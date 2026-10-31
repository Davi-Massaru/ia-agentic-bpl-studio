"""UI shell checks; these deliberately do not certify missing workflow features."""
from html.parser import HTMLParser
import pytest
from studio import create_app


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.headings = 0
        self.ids = []
        self.language = None
        self.labels = []
        self.tab_controls = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a":
            self.links.append(attrs)
        if tag == "h1":
            self.headings += 1
        if tag == "html":
            self.language = attrs.get("lang")
        if attrs.get("id"):
            self.ids.append(attrs["id"])
        if tag == "label" and attrs.get("for"):
            self.labels.append(attrs["for"])
        if attrs.get("role") == "tab":
            self.tab_controls.append(attrs.get("aria-controls"))


@pytest.mark.parametrize("path", ["/", "/designer", "/test-trace", "/publisher"])
@pytest.mark.parametrize("prefix", ["", "/studio"])
def test_navigation_preserves_wsgi_mount_and_identifies_current_page(path, prefix):
    client = create_app({"TESTING": True}).test_client()
    response = client.get(path, environ_overrides={"SCRIPT_NAME": prefix})
    assert response.status_code == 200
    markup = response.get_data(as_text=True)
    page = Page()
    page.feed(markup)
    assert page.headings == 1
    assert page.language == "en"
    assert len(page.ids) == len(set(page.ids))
    assert set(page.labels).issubset(page.ids)
    assert set(page.tab_controls).issubset(page.ids)
    assert 'aria-label="Studio screens"' in markup
    assert 'Connecting to the IRIS control plane' in markup
    expected_links = {prefix + route for route in ["/", "/designer", "/test-trace", "/publisher"]}
    native_links = {"/csp/user/EnsPortal.ProductionConfig.zen?$NAMESPACE=USER", "/csp/user/EnsPortal.BPLEditor.zen?$NAMESPACE=USER"} if path == "/" else set()
    assert {link["href"] for link in page.links} == expected_links | native_links
    current = [link for link in page.links if link.get("aria-current") == "page"]
    assert len(current) == 1 and current[0]["href"] == prefix + path
    assert f'href="{prefix}/static/style.css"' in markup
    assert f'src="{prefix}/static/studio.js"' in markup
    assert f'data-api="{prefix}/api/v1"' in markup
    assert 'class="warning"' in markup


def test_stylesheet_is_served_as_css():
    response = create_app({"TESTING": True}).test_client().get("/static/style.css")
    assert response.status_code == 200
    assert response.mimetype == "text/css"


def test_publisher_restores_releases_only_as_reviewable_drafts():
    markup = create_app({"TESTING": True}).test_client().get("/publisher").get_data(as_text=True)
    assert 'id="rollback-release"' in markup
    assert 'id="rollback-workflow" disabled' in markup
    assert 'Restore as new draft' in markup
    assert 'validate and review it before publishing' in markup


def test_designer_and_test_screen_explain_native_execution_boundaries():
    client = create_app({"TESTING": True}).test_client()
    designer = client.get('/designer').get_data(as_text=True)
    assert 'Insert in managed slot' in designer
    assert 'Typed fields from the Dictionary' in designer
    assert 'Validate and preview redacted input' in designer
    assert 'Example request fields · JSON' in designer
    assert 'placeholder=\'{"EventId":"example","Description":"..."}\'' in designer
    assert 'placeholder=\'{"request":' not in designer
    trace = client.get('/test-trace').get_data(as_text=True)
    assert 'SIMULATION — IRIS message, deterministic decision' in trace
    assert 'LIVE — AI Hub agent and provider' in trace
