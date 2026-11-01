/* Trace evidence renderer. All captured values are rendered as text, never markup. */
(function (root) {
  'use strict';
  function ordered(observations) {
    const rows = Array.isArray(observations) ? observations.filter(x => x && typeof x === 'object') : [];
    const ids = new Map(rows.map(x => [String(x.id), x]));
    const seen = new Set(), output = [];
    function parent(row) { return row.parentId || row.parentObservationId; }
    function visit(row, depth) {
      if (seen.has(row)) return;
      seen.add(row); output.push({row, depth});
      for (const child of rows) {
        if (parent(child) && String(parent(child)) === String(row.id)) visit(child, Math.min(depth + 1, 12));
      }
    }
    for (const row of rows) if (!parent(row) || !ids.has(String(parent(row)))) visit(row, 0);
    // Retain malformed/orphaned/cyclic evidence without infinite recursion or hidden rows.
    for (const row of rows) visit(row, 0);
    return output;
  }
  function duration(value) {
    return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value.toFixed(1) + ' ms' : 'Not captured';
  }
  function render(target, observations) {
    target.replaceChildren();
    const document = target.ownerDocument;
    function text(tag, value) { const el = document.createElement(tag); el.textContent = value; return el; }
    for (const {row, depth} of ordered(observations)) {
      const item = document.createElement('li');
      item.style.marginLeft = (depth * 1.1) + 'rem';
      item.append(text('strong', row.name || row.type || 'Observation'));
      item.append(text('small', [row.type, row.status || 'Unknown', duration(row.durationMs)].filter(Boolean).join(' · ')));
      const details = document.createElement('details');
      details.append(text('summary', 'Timing, correlation and captured metadata'));
      details.append(text('pre', JSON.stringify(row, null, 2)));
      item.append(details); target.append(item);
    }
    if (!target.children.length) target.append(text('li', 'No observations captured for this execution. Historical records may contain only native message events.'));
  }
  const api = {ordered, duration, render};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.StudioTraceView = api;
})(typeof window !== 'undefined' ? window : globalThis);

