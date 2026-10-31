const assert = require('node:assert/strict');
const {ordered, duration, render} = require('../backend/studio/static/trace-view.js');
const child = {id: 'child', parentId: 'root', name: '<img src=x onerror=alert(1)>', durationMs: 12, status: 'ERROR'};
const root = {id: 'root', name: 'Agent', type: 'agent', durationMs: 20};
assert.deepEqual(ordered([child, root]).map(x => [x.row.id, x.depth]), [['root', 0], ['child', 1]]);
assert.equal(ordered([{id: 'a', parentId: 'b'}, {id: 'b', parentId: 'a'}]).length, 2);
assert.equal(ordered([{id: 'orphan', parentId: 'absent'}])[0].depth, 0);
assert.equal(duration(0), '0.0 ms');
assert.equal(duration(null), 'Not captured');
assert.equal(duration(Infinity), 'Not captured');
class Element {
  constructor(tag) { this.tag = tag; this.children = []; this.style = {}; this.ownerDocument = doc; }
  append(...items) { this.children.push(...items); }
  replaceChildren() { this.children = []; }
  set innerHTML(value) { throw new Error('Untrusted HTML must not be inserted'); }
}
const doc = {createElement: tag => new Element(tag)};
const target = new Element('ol');
render(target, [child, root]);
assert.equal(target.children.length, 2);
assert.equal(target.children[1].children[0].textContent, child.name);
assert.equal(target.children[1].style.marginLeft, '1.1rem');
assert.match(target.children[1].children[1].textContent, /ERROR.*12.0 ms/);
render(target, undefined);
assert.equal(target.children.length, 1);
assert.match(target.children[0].textContent, /No observations captured/);
console.log('Trace hierarchy, missing timing, cycles, safe text rendering and legacy records passed.');
