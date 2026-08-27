use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

pub const NETWORK_CONTRACT_VERSION: &str = "1.0.0";

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum ConnectionPath {
    Direct,
    NatTraversal,
    Relay,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum ConnectionState {
    Resolving,
    ConnectingDirect,
    DirectFailed,
    ConnectingNat,
    NatFailed,
    ConnectingRelay,
    Connected,
    Disconnected,
    Failed,
    Cancelled,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum NetworkErrorCode {
    InvalidIntent,
    NetworkAuthorizationRequired,
    SessionExpired,
    ConnectionCancelled,
    RendezvousUnavailable,
    PeerNotFound,
    DirectConnectionFailed,
    NatTraversalFailed,
    RelayUnavailable,
    ConnectionTimeout,
    NetworkProtocolError,
    NetworkInternalError,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct NetworkError {
    pub code: NetworkErrorCode,
    pub message: String,
}

impl NetworkError {
    fn new(code: NetworkErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ConnectionIntent {
    pub session_id: String,
    pub organization_id: String,
    pub user_id: String,
    pub target_device_id: String,
    pub correlation_id: String,
    pub deadline_at_ms: u64,
    pub backend_authorized: bool,
}

impl ConnectionIntent {
    fn validate(&self, now_ms: u64) -> Result<(), NetworkError> {
        let values = [
            self.session_id.as_str(),
            self.organization_id.as_str(),
            self.user_id.as_str(),
            self.target_device_id.as_str(),
            self.correlation_id.as_str(),
        ];
        if values.iter().any(|value| value.trim().is_empty()) {
            return Err(NetworkError::new(
                NetworkErrorCode::InvalidIntent,
                "Connection intent contains an empty required identifier",
            ));
        }
        if !self.backend_authorized {
            return Err(NetworkError::new(
                NetworkErrorCode::NetworkAuthorizationRequired,
                "Backend authorization is required before networking",
            ));
        }
        if self.deadline_at_ms <= now_ms {
            return Err(NetworkError::new(
                NetworkErrorCode::SessionExpired,
                "The authorized session deadline has expired",
            ));
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ResolvedPeer {
    pub peer_id: String,
    pub direct_candidates: Vec<String>,
    pub nat_candidates: Vec<String>,
    pub relay_candidates: Vec<String>,
}

impl ResolvedPeer {
    fn has_candidates(&self, path: &ConnectionPath) -> bool {
        match path {
            ConnectionPath::Direct => !self.direct_candidates.is_empty(),
            ConnectionPath::NatTraversal => !self.nat_candidates.is_empty(),
            ConnectionPath::Relay => !self.relay_candidates.is_empty(),
        }
    }
}

pub trait RendezvousResolver: Send + Sync {
    fn resolve(&self, intent: &ConnectionIntent) -> Result<ResolvedPeer, NetworkError>;
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct NetworkConnection {
    pub connection_id: String,
    pub path: ConnectionPath,
    pub peer_id: String,
}

pub trait PathConnector: Send + Sync {
    fn connect(
        &self,
        intent: &ConnectionIntent,
        peer: &ResolvedPeer,
        path: ConnectionPath,
    ) -> Result<NetworkConnection, NetworkError>;
}

pub trait NetworkObserver: Send + Sync {
    fn observe(&self, event: &ConnectionEvent);
}

#[derive(Clone, Default)]
pub struct EventLog(Arc<std::sync::Mutex<Vec<ConnectionEvent>>>);

impl EventLog {
    pub fn events(&self) -> Vec<ConnectionEvent> {
        self.0
            .lock()
            .map(|events| events.clone())
            .unwrap_or_default()
    }
}

impl NetworkObserver for EventLog {
    fn observe(&self, event: &ConnectionEvent) {
        if let Ok(mut events) = self.0.lock() {
            events.push(event.clone());
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct ConnectionEvent {
    pub session_id: String,
    pub connection_id: Option<String>,
    pub target_device_id: String,
    pub correlation_id: String,
    pub state: ConnectionState,
    pub connection_path: Option<ConnectionPath>,
    pub failure_reason: Option<NetworkErrorCode>,
    pub relay_used: bool,
}

#[derive(Clone, Default)]
pub struct CancellationToken(Arc<AtomicBool>);

impl From<bool> for CancellationToken {
    fn from(value: bool) -> Self {
        let token = Self::default();
        if value {
            token.cancel();
        }
        token
    }
}

impl CancellationToken {
    pub fn cancel(&self) {
        self.0.store(true, Ordering::SeqCst);
    }

    pub fn is_cancelled(&self) -> bool {
        self.0.load(Ordering::SeqCst)
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct NetworkAttemptReport {
    pub connection: Option<NetworkConnection>,
    pub events: Vec<ConnectionEvent>,
    pub error: Option<NetworkError>,
}

pub struct UnconfiguredRendezvousResolver;

impl RendezvousResolver for UnconfiguredRendezvousResolver {
    fn resolve(&self, _intent: &ConnectionIntent) -> Result<ResolvedPeer, NetworkError> {
        Err(NetworkError::new(
            NetworkErrorCode::RendezvousUnavailable,
            "No rendezvous provider is configured",
        ))
    }
}

pub struct UnconfiguredPathConnector;

impl PathConnector for UnconfiguredPathConnector {
    fn connect(
        &self,
        _intent: &ConnectionIntent,
        _peer: &ResolvedPeer,
        _path: ConnectionPath,
    ) -> Result<NetworkConnection, NetworkError> {
        Err(NetworkError::new(
            NetworkErrorCode::NetworkInternalError,
            "No RustDesk networking provider is configured",
        ))
    }
}

pub fn fail_closed_connect(
    intent: &ConnectionIntent,
    now_ms: u64,
    cancellation: &CancellationToken,
) -> NetworkAttemptReport {
    let observer = EventLog::default();
    let orchestrator = NetworkConnectionOrchestrator::new(
        UnconfiguredRendezvousResolver,
        UnconfiguredPathConnector,
        observer.clone(),
    );
    let result = orchestrator.connect(intent, now_ms, cancellation);
    NetworkAttemptReport {
        connection: result.as_ref().ok().cloned(),
        events: observer.events(),
        error: result.err(),
    }
}

pub struct NetworkConnectionOrchestrator<R, C, O> {
    rendezvous: R,
    connector: C,
    observer: O,
}

impl<R, C, O> NetworkConnectionOrchestrator<R, C, O>
where
    R: RendezvousResolver,
    C: PathConnector,
    O: NetworkObserver,
{
    pub fn new(rendezvous: R, connector: C, observer: O) -> Self {
        Self {
            rendezvous,
            connector,
            observer,
        }
    }

    pub fn connect(
        &self,
        intent: &ConnectionIntent,
        now_ms: u64,
        cancellation: &CancellationToken,
    ) -> Result<NetworkConnection, NetworkError> {
        intent.validate(now_ms)?;
        if cancellation.is_cancelled() {
            return self.fail(intent, None, NetworkErrorCode::ConnectionCancelled);
        }
        self.emit(intent, None, None, ConnectionState::Resolving, None, false);
        let peer = match self.rendezvous.resolve(intent) {
            Ok(peer) if !peer.peer_id.trim().is_empty() => peer,
            Ok(_) => {
                return self.fail(intent, None, NetworkErrorCode::PeerNotFound);
            }
            Err(error) => {
                self.emit(
                    intent,
                    None,
                    None,
                    ConnectionState::Failed,
                    Some(error.code.clone()),
                    false,
                );
                return Err(error);
            }
        };

        let paths = [
            (
                ConnectionPath::Direct,
                ConnectionState::ConnectingDirect,
                ConnectionState::DirectFailed,
            ),
            (
                ConnectionPath::NatTraversal,
                ConnectionState::ConnectingNat,
                ConnectionState::NatFailed,
            ),
            (
                ConnectionPath::Relay,
                ConnectionState::ConnectingRelay,
                ConnectionState::Failed,
            ),
        ];
        for (path, connecting_state, failure_state) in paths {
            if cancellation.is_cancelled() {
                return self.fail(intent, None, NetworkErrorCode::ConnectionCancelled);
            }
            if now_ms >= intent.deadline_at_ms {
                return self.fail(intent, Some(path), NetworkErrorCode::ConnectionTimeout);
            }
            if !peer.has_candidates(&path) {
                self.emit(
                    intent,
                    None,
                    Some(path.clone()),
                    failure_state,
                    Some(match path {
                        ConnectionPath::Direct => NetworkErrorCode::DirectConnectionFailed,
                        ConnectionPath::NatTraversal => NetworkErrorCode::NatTraversalFailed,
                        ConnectionPath::Relay => NetworkErrorCode::RelayUnavailable,
                    }),
                    path == ConnectionPath::Relay,
                );
                continue;
            }
            self.emit(
                intent,
                None,
                Some(path.clone()),
                connecting_state,
                None,
                path == ConnectionPath::Relay,
            );
            match self.connector.connect(intent, &peer, path.clone()) {
                Ok(connection) => {
                    self.emit(
                        intent,
                        Some(connection.connection_id.clone()),
                        Some(connection.path.clone()),
                        ConnectionState::Connected,
                        None,
                        connection.path == ConnectionPath::Relay,
                    );
                    return Ok(connection);
                }
                Err(error) => {
                    self.emit(
                        intent,
                        None,
                        Some(path.clone()),
                        failure_state,
                        Some(error.code.clone()),
                        path == ConnectionPath::Relay,
                    );
                }
            }
        }
        self.fail(
            intent,
            Some(ConnectionPath::Relay),
            NetworkErrorCode::RelayUnavailable,
        )
    }

    pub fn disconnect(
        &self,
        intent: &ConnectionIntent,
        connection: &NetworkConnection,
    ) -> Result<(), NetworkError> {
        self.emit(
            intent,
            Some(connection.connection_id.clone()),
            Some(connection.path.clone()),
            ConnectionState::Disconnected,
            None,
            connection.path == ConnectionPath::Relay,
        );
        Ok(())
    }

    fn fail(
        &self,
        intent: &ConnectionIntent,
        path: Option<ConnectionPath>,
        code: NetworkErrorCode,
    ) -> Result<NetworkConnection, NetworkError> {
        let state = if code == NetworkErrorCode::ConnectionCancelled {
            ConnectionState::Cancelled
        } else {
            ConnectionState::Failed
        };
        self.emit(
            intent,
            None,
            path.clone(),
            state,
            Some(code.clone()),
            path == Some(ConnectionPath::Relay),
        );
        Err(NetworkError::new(
            code,
            "Network connection could not be established",
        ))
    }

    fn emit(
        &self,
        intent: &ConnectionIntent,
        connection_id: Option<String>,
        connection_path: Option<ConnectionPath>,
        state: ConnectionState,
        failure_reason: Option<NetworkErrorCode>,
        relay_used: bool,
    ) {
        self.observer.observe(&ConnectionEvent {
            session_id: intent.session_id.clone(),
            connection_id,
            target_device_id: intent.target_device_id.clone(),
            correlation_id: intent.correlation_id.clone(),
            state,
            connection_path,
            failure_reason,
            relay_used,
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    struct FixedResolver {
        peer: ResolvedPeer,
    }

    impl RendezvousResolver for FixedResolver {
        fn resolve(&self, _intent: &ConnectionIntent) -> Result<ResolvedPeer, NetworkError> {
            Ok(self.peer.clone())
        }
    }

    struct ScriptedConnector {
        failures: Mutex<Vec<Result<NetworkConnection, NetworkError>>>,
    }

    struct LoopbackConnector {
        address: String,
    }

    impl PathConnector for LoopbackConnector {
        fn connect(
            &self,
            _intent: &ConnectionIntent,
            peer: &ResolvedPeer,
            path: ConnectionPath,
        ) -> Result<NetworkConnection, NetworkError> {
            if path != ConnectionPath::Direct {
                return Err(NetworkError::new(
                    NetworkErrorCode::DirectConnectionFailed,
                    "Loopback test connector only supports direct path",
                ));
            }
            std::net::TcpStream::connect(&self.address).map_err(|_| {
                NetworkError::new(
                    NetworkErrorCode::DirectConnectionFailed,
                    "Loopback connection failed",
                )
            })?;
            Ok(NetworkConnection {
                connection_id: "loopback-connection".into(),
                path,
                peer_id: peer.peer_id.clone(),
            })
        }
    }

    impl PathConnector for ScriptedConnector {
        fn connect(
            &self,
            _intent: &ConnectionIntent,
            _peer: &ResolvedPeer,
            _path: ConnectionPath,
        ) -> Result<NetworkConnection, NetworkError> {
            self.failures.lock().unwrap().remove(0)
        }
    }

    #[derive(Default)]
    struct Events(Mutex<Vec<ConnectionEvent>>);

    impl NetworkObserver for Events {
        fn observe(&self, event: &ConnectionEvent) {
            self.0.lock().unwrap().push(event.clone());
        }
    }

    impl NetworkObserver for &Events {
        fn observe(&self, event: &ConnectionEvent) {
            self.0.lock().unwrap().push(event.clone());
        }
    }

    fn intent() -> ConnectionIntent {
        ConnectionIntent {
            session_id: "session-1".into(),
            organization_id: "tenant-1".into(),
            user_id: "user-1".into(),
            target_device_id: "device-1".into(),
            correlation_id: "correlation-1".into(),
            deadline_at_ms: 10_000,
            backend_authorized: true,
        }
    }

    fn failure(code: NetworkErrorCode) -> Result<NetworkConnection, NetworkError> {
        Err(NetworkError::new(code, "scripted failure"))
    }

    #[test]
    fn deterministic_fallback_reaches_relay_after_direct_and_nat_failures() {
        let events = Events::default();
        let orchestrator = NetworkConnectionOrchestrator::new(
            FixedResolver {
                peer: ResolvedPeer {
                    peer_id: "peer-1".into(),
                    direct_candidates: vec!["direct".into()],
                    nat_candidates: vec!["nat".into()],
                    relay_candidates: vec!["relay".into()],
                },
            },
            ScriptedConnector {
                failures: Mutex::new(vec![
                    failure(NetworkErrorCode::DirectConnectionFailed),
                    failure(NetworkErrorCode::NatTraversalFailed),
                    Ok(NetworkConnection {
                        connection_id: "connection-1".into(),
                        path: ConnectionPath::Relay,
                        peer_id: "peer-1".into(),
                    }),
                ]),
            },
            &events,
        );
        let result = orchestrator.connect(&intent(), 1_000, &CancellationToken::default());
        assert_eq!(result.unwrap().path, ConnectionPath::Relay);
        let states: Vec<ConnectionState> = events
            .0
            .lock()
            .unwrap()
            .iter()
            .map(|e| e.state.clone())
            .collect();
        assert_eq!(
            states,
            vec![
                ConnectionState::Resolving,
                ConnectionState::ConnectingDirect,
                ConnectionState::DirectFailed,
                ConnectionState::ConnectingNat,
                ConnectionState::NatFailed,
                ConnectionState::ConnectingRelay,
                ConnectionState::Connected,
            ]
        );
    }

    #[test]
    fn local_loopback_direct_connection_is_observable() {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap().to_string();
        let accept = std::thread::spawn(move || listener.accept().unwrap());
        let events = Events::default();
        let orchestrator = NetworkConnectionOrchestrator::new(
            FixedResolver {
                peer: ResolvedPeer {
                    peer_id: "peer-loopback".into(),
                    direct_candidates: vec![address.clone()],
                    nat_candidates: vec![],
                    relay_candidates: vec![],
                },
            },
            LoopbackConnector { address },
            &events,
        );
        let connection = orchestrator
            .connect(&intent(), 1_000, &CancellationToken::default())
            .unwrap();
        assert_eq!(connection.path, ConnectionPath::Direct);
        assert_eq!(accept.join().unwrap().1.ip().to_string(), "127.0.0.1");
        let events = events.0.lock().unwrap();
        assert!(events
            .iter()
            .any(|event| event.state == ConnectionState::Connected));
        assert!(events
            .iter()
            .any(|event| event.connection_path == Some(ConnectionPath::Direct)));
    }

    #[test]
    fn expired_or_unauthorized_intent_never_reaches_a_connector() {
        let events = Events::default();
        let orchestrator = NetworkConnectionOrchestrator::new(
            FixedResolver {
                peer: ResolvedPeer {
                    peer_id: "peer-1".into(),
                    direct_candidates: vec![],
                    nat_candidates: vec![],
                    relay_candidates: vec![],
                },
            },
            ScriptedConnector {
                failures: Mutex::new(vec![]),
            },
            &events,
        );
        let mut unauthorized = intent();
        unauthorized.backend_authorized = false;
        assert_eq!(
            orchestrator
                .connect(&unauthorized, 1_000, &CancellationToken::default())
                .unwrap_err()
                .code,
            NetworkErrorCode::NetworkAuthorizationRequired
        );
        let mut expired = intent();
        expired.deadline_at_ms = 1_000;
        assert_eq!(
            orchestrator
                .connect(&expired, 1_000, &CancellationToken::default())
                .unwrap_err()
                .code,
            NetworkErrorCode::SessionExpired
        );
        assert!(events.0.lock().unwrap().is_empty());
    }

    #[test]
    fn cancellation_stops_before_resolution_or_after_failure() {
        let events = Events::default();
        let orchestrator = NetworkConnectionOrchestrator::new(
            FixedResolver {
                peer: ResolvedPeer {
                    peer_id: "peer-1".into(),
                    direct_candidates: vec![],
                    nat_candidates: vec![],
                    relay_candidates: vec![],
                },
            },
            ScriptedConnector {
                failures: Mutex::new(vec![]),
            },
            &events,
        );
        let cancellation = CancellationToken::default();
        cancellation.cancel();
        assert_eq!(
            orchestrator
                .connect(&intent(), 1_000, &cancellation)
                .unwrap_err()
                .code,
            NetworkErrorCode::ConnectionCancelled
        );
        assert_eq!(
            events.0.lock().unwrap().last().unwrap().state,
            ConnectionState::Cancelled
        );
    }
}
