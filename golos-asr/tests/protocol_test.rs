use golos_asr::protocol::{Request, Response};

#[test]
fn request_load_round_trip() {
    let r = Request::Load { model_path: "/tmp/model".into() };
    let json = serde_json::to_string(&r).unwrap();
    assert_eq!(json, r#"{"type":"load","model_path":"/tmp/model"}"#);
    let back: Request = serde_json::from_str(&json).unwrap();
    assert_eq!(r, back);
}

#[test]
fn request_begin_session_round_trip() {
    let r = Request::BeginSession;
    let json = serde_json::to_string(&r).unwrap();
    assert_eq!(json, r#"{"type":"begin_session"}"#);
    let back: Request = serde_json::from_str(&json).unwrap();
    assert_eq!(r, back);
}

#[test]
fn response_final_round_trip() {
    let r = Response::Final {
        text: "привет мир".into(),
        duration_ms: 1234,
    };
    let json = serde_json::to_string(&r).unwrap();
    assert_eq!(json, r#"{"type":"final","text":"привет мир","duration_ms":1234}"#);
}

#[test]
fn response_error_serializes_with_kind_and_message() {
    let r = Response::Error {
        kind: "model_not_loaded".into(),
        message: "call load first".into(),
    };
    let json = serde_json::to_string(&r).unwrap();
    assert!(json.contains(r#""type":"error""#));
    assert!(json.contains(r#""kind":"model_not_loaded""#));
}

#[test]
fn unknown_request_type_returns_err() {
    let bad = r#"{"type":"unknown_op"}"#;
    let parsed: Result<Request, _> = serde_json::from_str(bad);
    assert!(parsed.is_err());
}
