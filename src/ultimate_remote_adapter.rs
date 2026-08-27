use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};

use crate::ultimate_remote_network::{
    fail_closed_connect, CancellationToken, ConnectionIntent, NetworkAttemptReport,
};

pub const FFI_CONTRACT_VERSION: &str = "1.0.0";

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum UltimateRemoteSessionState {
    Authorized,
    Connecting,
    Connected,
    Disconnected,
    Closed,
    Failed,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum UltimateRemoteErrorCode {
    InvalidInput,
    FfiInitializationFailed,
    RustInitializationFailed,
    SessionNotFound,
    InvalidSessionState,
    AuthorizationRequired,
    Internal,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct UltimateRemoteError {
    pub code: UltimateRemoteErrorCode,
    pub message: String,
}

impl UltimateRemoteError {
    fn new(code: UltimateRemoteErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct UltimateRemoteSessionContext {
    pub session_id: String,
    pub organization_id: String,
    pub user_id: String,
    pub source_device_id: Option<String>,
    pub target_device_id: String,
    pub correlation_id: String,
    pub backend_authorized: bool,
}

impl UltimateRemoteSessionContext {
    fn validate(&self) -> Result<(), UltimateRemoteError> {
        let required = [
            ("session_id", self.session_id.as_str()),
            ("organization_id", self.organization_id.as_str()),
            ("user_id", self.user_id.as_str()),
            ("target_device_id", self.target_device_id.as_str()),
            ("correlation_id", self.correlation_id.as_str()),
        ];
        if required.iter().any(|(_, value)| value.trim().is_empty()) {
            return Err(UltimateRemoteError::new(
                UltimateRemoteErrorCode::InvalidInput,
                "Session context contains an empty required identifier",
            ));
        }
        if self
            .source_device_id
            .as_deref()
            .is_some_and(|value| value.trim().is_empty())
        {
            return Err(UltimateRemoteError::new(
                UltimateRemoteErrorCode::InvalidInput,
                "Source device identifier cannot be empty",
            ));
        }
        if !self.backend_authorized {
            return Err(UltimateRemoteError::new(
                UltimateRemoteErrorCode::AuthorizationRequired,
                "Backend authorization is required before FFI session creation",
            ));
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct UltimateRemoteSession {
    pub context: UltimateRemoteSessionContext,
    pub state: UltimateRemoteSessionState,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum UltimateRemoteEventKind {
    Initialized,
    SessionCreated,
    Connecting,
    Connected,
    Disconnected,
    Closed,
    Error,
    Shutdown,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct UltimateRemoteEvent {
    pub kind: UltimateRemoteEventKind,
    pub session_id: Option<String>,
    pub correlation_id: Option<String>,
    pub state: Option<UltimateRemoteSessionState>,
    pub error: Option<UltimateRemoteError>,
}

pub trait RustDeskCoreBoundary: Send + Sync + 'static {
    fn initialize(&self) -> Result<(), UltimateRemoteError>;
    fn create_session(
        &self,
        context: UltimateRemoteSessionContext,
    ) -> Result<UltimateRemoteSession, UltimateRemoteError>;
    fn start_session(&self, session_id: &str)
        -> Result<UltimateRemoteSession, UltimateRemoteError>;
    fn stop_session(&self, session_id: &str) -> Result<UltimateRemoteSession, UltimateRemoteError>;
    fn session_context(
        &self,
        session_id: &str,
    ) -> Result<UltimateRemoteSessionContext, UltimateRemoteError>;
    fn shutdown(&self) -> Result<(), UltimateRemoteError>;
}

#[derive(Default)]
pub struct LocalCoreBoundary {
    initialized: Mutex<bool>,
    sessions: Mutex<BTreeMap<String, UltimateRemoteSession>>,
}

impl RustDeskCoreBoundary for LocalCoreBoundary {
    fn initialize(&self) -> Result<(), UltimateRemoteError> {
        let mut initialized = self.initialized.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::RustInitializationFailed,
                "Rust core initialization state is unavailable",
            )
        })?;
        *initialized = true;
        Ok(())
    }

    fn create_session(
        &self,
        context: UltimateRemoteSessionContext,
    ) -> Result<UltimateRemoteSession, UltimateRemoteError> {
        context.validate()?;
        if !*self.initialized.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::FfiInitializationFailed,
                "FFI initialization state is unavailable",
            )
        })? {
            return Err(UltimateRemoteError::new(
                UltimateRemoteErrorCode::FfiInitializationFailed,
                "FFI must be initialized before creating a session",
            ));
        }
        let mut sessions = self.sessions.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::Internal,
                "Session registry is unavailable",
            )
        })?;
        if sessions.contains_key(&context.session_id) {
            return Err(UltimateRemoteError::new(
                UltimateRemoteErrorCode::InvalidSessionState,
                "Session already exists",
            ));
        }
        let session = UltimateRemoteSession {
            context,
            state: UltimateRemoteSessionState::Authorized,
        };
        sessions.insert(session.context.session_id.clone(), session.clone());
        Ok(session)
    }

    fn start_session(
        &self,
        session_id: &str,
    ) -> Result<UltimateRemoteSession, UltimateRemoteError> {
        let mut sessions = self.sessions.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::Internal,
                "Session registry is unavailable",
            )
        })?;
        let session = sessions.get_mut(session_id).ok_or_else(|| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::SessionNotFound,
                "Session not found",
            )
        })?;
        if session.state != UltimateRemoteSessionState::Authorized {
            return Err(UltimateRemoteError::new(
                UltimateRemoteErrorCode::InvalidSessionState,
                "Only an authorized session can be started",
            ));
        }
        session.state = UltimateRemoteSessionState::Connected;
        Ok(session.clone())
    }

    fn stop_session(&self, session_id: &str) -> Result<UltimateRemoteSession, UltimateRemoteError> {
        let mut sessions = self.sessions.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::Internal,
                "Session registry is unavailable",
            )
        })?;
        let session = sessions.get_mut(session_id).ok_or_else(|| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::SessionNotFound,
                "Session not found",
            )
        })?;
        if session.state != UltimateRemoteSessionState::Closed {
            session.state = UltimateRemoteSessionState::Closed;
        }
        Ok(session.clone())
    }

    fn session_context(
        &self,
        session_id: &str,
    ) -> Result<UltimateRemoteSessionContext, UltimateRemoteError> {
        self.sessions
            .lock()
            .map_err(|_| {
                UltimateRemoteError::new(
                    UltimateRemoteErrorCode::Internal,
                    "Session registry is unavailable",
                )
            })?
            .get(session_id)
            .map(|session| session.context.clone())
            .ok_or_else(|| {
                UltimateRemoteError::new(
                    UltimateRemoteErrorCode::SessionNotFound,
                    "Session not found",
                )
            })
    }

    fn shutdown(&self) -> Result<(), UltimateRemoteError> {
        let mut sessions = self.sessions.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::Internal,
                "Session registry is unavailable",
            )
        })?;
        sessions.clear();
        let mut initialized = self.initialized.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::RustInitializationFailed,
                "Rust core initialization state is unavailable",
            )
        })?;
        *initialized = false;
        Ok(())
    }
}

pub struct UltimateRemoteRustAdapter<B: RustDeskCoreBoundary> {
    backend: Arc<B>,
    events: Mutex<Vec<UltimateRemoteEvent>>,
    callback: Mutex<Option<Arc<dyn Fn(UltimateRemoteEvent) + Send + Sync>>>,
    shutdown: Mutex<bool>,
}

impl<B: RustDeskCoreBoundary> UltimateRemoteRustAdapter<B> {
    pub fn new(backend: Arc<B>) -> Self {
        Self {
            backend,
            events: Mutex::new(Vec::new()),
            callback: Mutex::new(None),
            shutdown: Mutex::new(false),
        }
    }

    pub fn set_event_callback(
        &self,
        callback: Option<Arc<dyn Fn(UltimateRemoteEvent) + Send + Sync>>,
    ) -> Result<(), UltimateRemoteError> {
        let mut current = self.callback.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::Internal,
                "Event callback state is unavailable",
            )
        })?;
        *current = callback;
        Ok(())
    }

    pub fn initialize(&self) -> Result<(), UltimateRemoteError> {
        if *self.shutdown.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::Internal,
                "Adapter lifecycle state is unavailable",
            )
        })? {
            return Err(UltimateRemoteError::new(
                UltimateRemoteErrorCode::FfiInitializationFailed,
                "Adapter cannot be initialized after shutdown",
            ));
        }
        self.backend.initialize().map_err(|error| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::RustInitializationFailed,
                error.message,
            )
        })?;
        self.emit(UltimateRemoteEvent {
            kind: UltimateRemoteEventKind::Initialized,
            session_id: None,
            correlation_id: None,
            state: None,
            error: None,
        })?;
        Ok(())
    }

    pub fn create_session(
        &self,
        context: UltimateRemoteSessionContext,
    ) -> Result<UltimateRemoteSession, UltimateRemoteError> {
        self.ensure_running()?;
        let session = self.backend.create_session(context)?;
        self.emit(UltimateRemoteEvent {
            kind: UltimateRemoteEventKind::SessionCreated,
            session_id: Some(session.context.session_id.clone()),
            correlation_id: Some(session.context.correlation_id.clone()),
            state: Some(session.state.clone()),
            error: None,
        })?;
        Ok(session)
    }

    pub fn start_session(
        &self,
        session_id: &str,
    ) -> Result<UltimateRemoteSession, UltimateRemoteError> {
        self.ensure_running()?;
        let session = self.backend.start_session(session_id)?;
        self.emit(UltimateRemoteEvent {
            kind: UltimateRemoteEventKind::Connecting,
            session_id: Some(session.context.session_id.clone()),
            correlation_id: Some(session.context.correlation_id.clone()),
            state: Some(UltimateRemoteSessionState::Connecting),
            error: None,
        })?;
        self.emit(UltimateRemoteEvent {
            kind: UltimateRemoteEventKind::Connected,
            session_id: Some(session.context.session_id.clone()),
            correlation_id: Some(session.context.correlation_id.clone()),
            state: Some(session.state.clone()),
            error: None,
        })?;
        Ok(session)
    }

    pub fn connect_network(
        &self,
        intent: ConnectionIntent,
        now_ms: u64,
        cancellation: &CancellationToken,
    ) -> Result<NetworkAttemptReport, UltimateRemoteError> {
        self.ensure_running()?;
        let context = self.backend.session_context(&intent.session_id)?;
        if context.organization_id != intent.organization_id
            || context.user_id != intent.user_id
            || context.target_device_id != intent.target_device_id
            || context.correlation_id != intent.correlation_id
            || !context.backend_authorized
            || !intent.backend_authorized
        {
            return Err(UltimateRemoteError::new(
                UltimateRemoteErrorCode::AuthorizationRequired,
                "Network intent does not match the authorized session",
            ));
        }
        let report = fail_closed_connect(&intent, now_ms, cancellation);
        if report.error.is_some() {
            self.emit(UltimateRemoteEvent {
                kind: UltimateRemoteEventKind::Error,
                session_id: Some(context.session_id),
                correlation_id: Some(context.correlation_id),
                state: Some(UltimateRemoteSessionState::Failed),
                error: Some(UltimateRemoteError::new(
                    UltimateRemoteErrorCode::Internal,
                    "Network connection failed",
                )),
            })?;
        } else {
            self.emit(UltimateRemoteEvent {
                kind: UltimateRemoteEventKind::Connected,
                session_id: Some(context.session_id),
                correlation_id: Some(context.correlation_id),
                state: Some(UltimateRemoteSessionState::Connected),
                error: None,
            })?;
        }
        Ok(report)
    }

    pub fn stop_session(
        &self,
        session_id: &str,
    ) -> Result<UltimateRemoteSession, UltimateRemoteError> {
        self.ensure_running()?;
        let session = self.backend.stop_session(session_id)?;
        self.emit(UltimateRemoteEvent {
            kind: UltimateRemoteEventKind::Closed,
            session_id: Some(session.context.session_id.clone()),
            correlation_id: Some(session.context.correlation_id.clone()),
            state: Some(session.state.clone()),
            error: None,
        })?;
        Ok(session)
    }

    pub fn shutdown(&self) -> Result<(), UltimateRemoteError> {
        let mut shutdown = self.shutdown.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::Internal,
                "Adapter lifecycle state is unavailable",
            )
        })?;
        if *shutdown {
            return Ok(());
        }
        self.backend.shutdown()?;
        *shutdown = true;
        let mut callback = self.callback.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::Internal,
                "Event callback state is unavailable",
            )
        })?;
        *callback = None;
        drop(callback);
        self.emit_without_callback(UltimateRemoteEvent {
            kind: UltimateRemoteEventKind::Shutdown,
            session_id: None,
            correlation_id: None,
            state: None,
            error: None,
        })
    }

    pub fn drain_events(&self) -> Result<Vec<UltimateRemoteEvent>, UltimateRemoteError> {
        let mut events = self.events.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::Internal,
                "Event queue is unavailable",
            )
        })?;
        Ok(std::mem::take(&mut *events))
    }

    fn ensure_running(&self) -> Result<(), UltimateRemoteError> {
        if *self.shutdown.lock().map_err(|_| {
            UltimateRemoteError::new(
                UltimateRemoteErrorCode::Internal,
                "Adapter lifecycle state is unavailable",
            )
        })? {
            return Err(UltimateRemoteError::new(
                UltimateRemoteErrorCode::FfiInitializationFailed,
                "Adapter has been shut down",
            ));
        }
        Ok(())
    }

    fn emit(&self, event: UltimateRemoteEvent) -> Result<(), UltimateRemoteError> {
        self.emit_without_callback(event.clone())?;
        let callback = self
            .callback
            .lock()
            .map_err(|_| {
                UltimateRemoteError::new(
                    UltimateRemoteErrorCode::Internal,
                    "Event callback state is unavailable",
                )
            })?
            .clone();
        if let Some(callback) = callback {
            callback(event);
        }
        Ok(())
    }

    fn emit_without_callback(&self, event: UltimateRemoteEvent) -> Result<(), UltimateRemoteError> {
        self.events
            .lock()
            .map_err(|_| {
                UltimateRemoteError::new(
                    UltimateRemoteErrorCode::Internal,
                    "Event queue is unavailable",
                )
            })?
            .push(event);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ultimate_remote_network::NetworkErrorCode;

    fn context() -> UltimateRemoteSessionContext {
        UltimateRemoteSessionContext {
            session_id: "session-1".into(),
            organization_id: "tenant-1".into(),
            user_id: "user-1".into(),
            source_device_id: Some("source-1".into()),
            target_device_id: "target-1".into(),
            correlation_id: "correlation-1".into(),
            backend_authorized: true,
        }
    }

    #[test]
    fn local_core_lifecycle_is_deterministic_and_duplicate_stop_is_safe() {
        let adapter = UltimateRemoteRustAdapter::new(Arc::new(LocalCoreBoundary::default()));
        adapter.initialize().expect("initialize");
        let session = adapter.create_session(context()).expect("create");
        assert_eq!(session.state, UltimateRemoteSessionState::Authorized);
        let started = adapter.start_session("session-1").expect("start");
        assert_eq!(started.state, UltimateRemoteSessionState::Connected);
        let stopped = adapter.stop_session("session-1").expect("stop");
        assert_eq!(stopped.state, UltimateRemoteSessionState::Closed);
        let stopped_again = adapter.stop_session("session-1").expect("duplicate stop");
        assert_eq!(stopped_again.state, UltimateRemoteSessionState::Closed);
        let events = adapter.drain_events().expect("events");
        assert_eq!(events.len(), 6);
    }

    #[test]
    fn invalid_context_and_duplicate_session_are_rejected() {
        let adapter = UltimateRemoteRustAdapter::new(Arc::new(LocalCoreBoundary::default()));
        adapter.initialize().expect("initialize");
        let mut invalid = context();
        invalid.backend_authorized = false;
        assert_eq!(
            adapter.create_session(invalid).unwrap_err().code,
            UltimateRemoteErrorCode::AuthorizationRequired
        );
        adapter.create_session(context()).expect("create");
        assert_eq!(
            adapter.create_session(context()).unwrap_err().code,
            UltimateRemoteErrorCode::InvalidSessionState
        );
    }

    #[test]
    fn networking_requires_matching_authorized_session_context() {
        let adapter = UltimateRemoteRustAdapter::new(Arc::new(LocalCoreBoundary::default()));
        adapter.initialize().expect("initialize");
        adapter.create_session(context()).expect("create");
        let intent = ConnectionIntent {
            session_id: "session-1".into(),
            organization_id: "tenant-1".into(),
            user_id: "user-1".into(),
            target_device_id: "target-1".into(),
            correlation_id: "correlation-1".into(),
            deadline_at_ms: 10_000,
            backend_authorized: true,
        };
        let report = adapter
            .connect_network(intent.clone(), 1_000, &CancellationToken::default())
            .expect("network report");
        assert_eq!(
            report.error.as_ref().unwrap().code,
            NetworkErrorCode::RendezvousUnavailable
        );
        let mut mismatched = intent;
        mismatched.target_device_id = "other-target".into();
        assert_eq!(
            adapter
                .connect_network(mismatched, 1_000, &CancellationToken::default())
                .unwrap_err()
                .code,
            UltimateRemoteErrorCode::AuthorizationRequired
        );
    }

    #[test]
    fn callback_is_not_called_after_shutdown() {
        let adapter = UltimateRemoteRustAdapter::new(Arc::new(LocalCoreBoundary::default()));
        let callbacks = Arc::new(Mutex::new(0usize));
        let count = Arc::clone(&callbacks);
        adapter
            .set_event_callback(Some(Arc::new(move |_| *count.lock().expect("lock") += 1)))
            .expect("callback");
        adapter.initialize().expect("initialize");
        adapter.shutdown().expect("shutdown");
        adapter.shutdown().expect("duplicate shutdown");
        assert_eq!(*callbacks.lock().expect("lock"), 1);
        assert_eq!(
            adapter.start_session("session-1").unwrap_err().code,
            UltimateRemoteErrorCode::FfiInitializationFailed
        );
    }
}
