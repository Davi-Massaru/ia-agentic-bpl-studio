import pytest
from studio.native.vector_retrieval import validate_query


@pytest.mark.parametrize('raw,k', [('[0,0,0]', 3), ('[1,2]', 3), ('[true,0,0]', 3),
    ('[NaN,0,0]', 3), ('[Infinity,0,0]', 3), ('[1,0,0]', 0), ('[1,0,0]', 11),
    ('[1,0,0]', True), ('[1000001,0,0]', 3), ('{}', 3)])
def test_invalid_queries_rejected(raw, k):
    with pytest.raises(ValueError):
        validate_query(raw, k)


def test_parameterized_vector_and_bounded_limit():
    assert validate_query('[1,0.5,-1]', 2) == ('1.0,0.5,-1.0', 2)
