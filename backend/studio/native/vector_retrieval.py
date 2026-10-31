"""Optional native Vector Search fixture; supplied vectors are NOT semantic embeddings."""
import json
import math
import time
from datetime import datetime, timezone


def validate_query(raw, top_k):
    if not isinstance(raw, str) or len(raw) > 256:
        raise ValueError('VECTOR_INVALID')
    vector = json.loads(raw)
    if not isinstance(vector, list) or len(vector) != 3:
        raise ValueError('VECTOR_DIMENSION_INVALID')
    if any(type(x) not in (int, float) or not math.isfinite(x) or abs(x) > 1e6 for x in vector):
        raise ValueError('VECTOR_VALUE_INVALID')
    if not any(vector):
        raise ValueError('VECTOR_ZERO')
    if type(top_k) is not int or not 1 <= top_k <= 10:
        raise ValueError('TOP_K_INVALID')
    return ','.join(str(float(x)) for x in vector), top_k


def search_fixture(raw, top_k=3):
    import iris
    start, started = time.perf_counter(), datetime.now(timezone.utc).isoformat()
    execution = str(iris.cls('Studio.Trace.Recorder').Execution() or '')
    from studio.native.tracing import native_start, native_finish
    observation = native_start(execution, execution, str(iris.cls('Studio.Trace.Recorder').Parent() or ''), 'retrieval', 'IRIS Vector Search') if execution else ''
    event = dict(name='SearchFixtureVectors', type='retrieval', effect='READ',
                 source='instrumented-tool', startedAt=started, status='ERROR',
                 metadata=dict(collection='StudioVector.TraceFixture', metric='cosine',
                               embeddingModel='synthetic-coordinate-v1', dimension=3,
                               synthetic=True, semanticEmbedding=False))
    try:
        vector, limit = validate_query(raw, top_k)
        # Only the bounded integer is interpolated. The supplied vector is a SQL parameter.
        sql = (f'SELECT TOP {limit} DocumentId, ContentHash, '
               'VECTOR_COSINE(ContentVector, TO_VECTOR(?, DOUBLE)) AS Score '
               'FROM StudioVector.TraceFixture ORDER BY Score DESC, DocumentId ASC')
        statement = iris.cls('%SQL.Statement')._New()
        status = statement._Prepare(sql)
        if iris.cls('%SYSTEM.Status').IsError(status):
            raise RuntimeError('VECTOR_FIXTURE_NOT_READY')
        rows = statement._Execute(vector)
        if rows._SQLCODE < 0:
            raise RuntimeError('VECTOR_QUERY_FAILED')
        documents = []
        while rows._Next():
            documents.append(dict(documentId=str(rows._Get('DocumentId')),
                                  contentHash=str(rows._Get('ContentHash')),
                                  score=float(rows._Get('Score'))))
        if rows._SQLCODE < 0:
            raise RuntimeError('VECTOR_QUERY_FAILED')
        result = dict(synthetic=True, semanticEmbedding=False, documents=documents)
        event['metadata'].update(topK=limit, documentIds=[d['documentId'] for d in documents], scores=[d['score'] for d in documents])
        event.update(status='SUCCESS', topK=limit, result=result)
        return json.dumps(result)
    except Exception as exc:
        event['errorCode'] = str(exc) if isinstance(exc, (ValueError, RuntimeError)) else 'VECTOR_QUERY_FAILED'
        raise
    finally:
        event.update(endedAt=datetime.now(timezone.utc).isoformat(),
                     durationMs=round((time.perf_counter() - start) * 1000, 3))
        if execution:
            native_finish(execution, observation, event['status'], json.dumps(event['metadata']))
            audit = iris.gref('^StudioAudit')
            index = iris.cls('Studio.Tools.VectorReadTools').NextObservation(execution)
            audit[execution, 'tools', index] = json.dumps(event)
