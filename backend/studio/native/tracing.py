"""Bounded payload-free observations persisted in IRIS, best-effort telemetry."""
import json
import time
import uuid
from datetime import datetime, timezone

CLOCKS = {}
ALLOWED = {'provider', 'model', 'agentId', 'agentRevision', 'operation', 'collection', 'metric', 'dimension', 'synthetic', 'semanticEmbedding', 'embeddingModel', 'documentIds', 'scores', 'topK'}
def clean(metadata):
    data = json.loads(metadata) if isinstance(metadata, str) else metadata
    return {k: v for k, v in data.items() if k in ALLOWED}

def native_start(execution, trace, parent, kind, name, metadata='{}'):
    if not execution:
        return ''
    try:
        import iris
        audit = iris.gref('^StudioAudit')
        rows = json.loads(audit[execution, 'observations'] or '[]')
        if len(rows) >= 64:
            return ''
        trace = next((r['traceId'] for r in rows if r['id'] == parent), trace)
        identifier = uuid.uuid4().hex
        rows.append(dict(id=identifier, executionId=execution, traceId=trace or execution,
            parentObservationId=parent, type=kind, name=name, status='RUNNING',
            startTime=datetime.now(timezone.utc).isoformat(), metadata=clean(metadata)))
        audit[execution, 'observations'] = json.dumps(rows)
        CLOCKS[identifier] = time.perf_counter()
        return identifier
    except Exception:
        return ''

def native_finish(execution, identifier, status, metadata='{}', usage='{}'):
    if not identifier:
        return
    try:
        import iris
        audit = iris.gref('^StudioAudit')
        rows = json.loads(audit[execution, 'observations'] or '[]')
        for row in rows:
            if row['id'] == identifier:
                row.update(status=status, endTime=datetime.now(timezone.utc).isoformat())
                started = CLOCKS.pop(identifier, None)
                if started:
                    row['durationMs'] = round(max(0, time.perf_counter()-float(started))*1000, 3)
                row['metadata'].update(clean(metadata))
                stats = json.loads(usage)
                row['usage'] = {k: v for k, v in stats.items() if isinstance(v, (int, float)) and not isinstance(v, bool)}
        audit[execution, 'observations'] = json.dumps(rows)
    except Exception:
        pass
