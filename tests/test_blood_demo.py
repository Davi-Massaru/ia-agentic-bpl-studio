from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def xdata(name, tag):
    source = (ROOT / 'src/iris/Studio/BloodDemo' / name).read_text(encoding='utf-8')
    start = source.index('<' + tag)
    end = source.index('</' + tag + '>') + len(tag) + 3
    return ET.fromstring(source[start:end])


def test_native_bpl_xml_targets_exist_and_cannot_be_chosen_by_model():
    # Structural check only. IRIS compilation and execution are separate gates.
    production = xdata('Production.cls', 'Production')
    bpl = xdata('Routing.cls', 'process')
    hosts = {item.attrib['Name'] for item in production.findall('Item')}
    calls = bpl.findall('.//call')
    assert {call.attrib['target'] for call in calls} == {
        'BloodDecision', 'HemocentroB', 'HemocentroC', 'Review'}
    assert all(call.attrib['target'] in hosts for call in calls)
    assert bpl.find('.//default/call').attrib['target'] == 'Review'
    assert len(bpl.findall('.//switch/case')) == 2
    for item in production.findall('Item'):
        path = ROOT / 'src/iris' / (item.attrib['ClassName'].replace('.', '/') + '.cls')
        assert path.is_file(), path
