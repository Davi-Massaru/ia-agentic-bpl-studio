import pytest
from studio.domain.mapping import MappingError, preview_inputs


def field(source="request.EventId", target="eventId", required=True):
    return {"source": source, "target": target, "required": required}


def test_preview_selects_only_authorized_fields_and_redacts_by_default():
    snapshot = {"request": {"EventId": "E-1", "Secret": "private", "Other": "omit"}}
    metadata = {"request.EventId": {"type": "string", "sensitive": False},
                "request.Secret": {"type": "string"}}
    assert preview_inputs([field(), field("request.Secret", "secret")], snapshot, metadata) == {
        "eventId": "E-1", "secret": "[REDACTED]"}


@pytest.mark.parametrize("source", ["request.__class__", "request.X[0]", "request.X()", "constant.exec"])
def test_executable_paths_rejected(source):
    with pytest.raises(MappingError, match="UNKNOWN_SOURCE"):
        preview_inputs([field(source)], {}, {source: {"type": "string"}})


def test_required_missing_optional_omitted():
    metadata = {"request.EventId": {"type": "string"}}
    assert preview_inputs([field(required=False)], {}, metadata) == {}
    with pytest.raises(MappingError, match="REQUIRED_INPUT_MISSING"):
        preview_inputs([field()], {}, metadata)


def test_bool_is_not_integer_and_errors_do_not_echo_values():
    with pytest.raises(MappingError, match="^INPUT_TYPE_MISMATCH$"):
        preview_inputs([field()], {"request": {"EventId": True}},
                       {"request.EventId": {"type": "integer"}})


def test_duplicate_targets_rejected():
    with pytest.raises(MappingError, match="INVALID_TARGET"):
        preview_inputs([field(), field()], {"request": {"EventId": "E-1"}},
                       {"request.EventId": {"type": "string"}})


def test_nested_containers_always_redacted():
    assert preview_inputs([field()], {"request": {"EventId": {"token": "secret"}}},
                          {"request.EventId": {"type": "object", "sensitive": False}}) == {
        "eventId": "[REDACTED]"}
