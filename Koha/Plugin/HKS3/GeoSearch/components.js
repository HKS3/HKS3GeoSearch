class GeoSearchForm extends HTMLElement {
    constructor() {
        super();
        this.form = document.createElement('form');
        this.form.setAttribute('method', 'get');
        this.form.setAttribute('action', "/cgi-bin/koha/opac-search.pl");
        this.form.innerHTML = `<fieldset>
            <label>Geographic Search</label>
            <div class="geo_search_map"></div>
            <input type="hidden" name="advsearch" value="1" />
            <input type="hidden" name="idx" value="geolocation" />
            <input type="hidden" name="do" value="Search" />
            <input id="geoquery" type="hidden" name="q" />
            <div>
                <input type="text" size="6" id="locationToGeocode" title="Lookup location" />
                <button type="button" id="lookupButton"> Lookup </button>
            </div>
            <label>
                <input type="checkbox" id="bboxSearch" title="Search visible area">
                Search visible area
            </label>
            <div class="hint">or...</div>
            <input type="text" size="6" id="lat" title="Enter Latitude">
            <input type="text" size="6" id="lng" title="Enter Longitude">
            <input type="text" size="6" id="rad" title="Enter Radius" value="120km" pattern="(\\d+)(k?m)?">
            <div class="hint">Search for Lat/long/Radius</div>
            <input type="submit" />
        </fieldset>
        `;
        this.appendChild(this.form);
    }

    get defaultPosition() {
        return JSON.parse(this.getAttribute('defaultPosition'));
    }

    get useBboxSearch() {
        return this.getElementById('bboxSearch').checked;
    }

    connectedCallback() {
        this.viewAdjusted = false;
        const mapContainer = this.querySelector('div.geo_search_map');
        this.map = L.map(mapContainer).setView(this.defaultPosition, 5);
        const tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        }).addTo(this.map);

        this.querySelector('input#lat').value = this.defaultPosition[0];
        this.querySelector('input#lng').value = this.defaultPosition[1];

        this.circle = L.circle(this.defaultPosition, { radius: 120_000 });
        this.circle.addTo(this.map);

        // Whenever a map is panned by the user
        // we instantly update the position of the displayed circle.
        // The coordinates in inputs do not get updated instantly, since that'd trigger a map movement as well.
        this.map.on('move', this.redrawCircle.bind(this));

        // Whenever a user stops messing with a map (releases a mouse button)
        // we update the input fields and the underlying query
        this.map.on('mouseup', this.updateInputs.bind(this));

        // When a user manually edits coordinates/radius
        // we update the displayed map and the underlying query.
        this.querySelector('input#lat').addEventListener('input', this.onInputUpdated.bind(this));
        this.querySelector('input#lng').addEventListener('input', this.onInputUpdated.bind(this));
        this.querySelector('input#rad').addEventListener('input', this.onInputUpdated.bind(this));

        this.getElementById('bboxSearch').onchange = () => {
            this.getElementById('lat').disabled = this.useBboxSearch;
            this.getElementById('lng').disabled = this.useBboxSearch;
            this.getElementById('rad').disabled = this.useBboxSearch;
            this.redrawCircle();
            this.updateGeoQuery();
        };

        this.getElementById('lookupButton').onclick = () => {
            const query = this.getElementById('locationToGeocode').value;
            $.ajax({
                type: 'GET',
                url: '/api/v1/contrib/geo_search/geocode?q=' + encodeURI(query),
                dataType: 'json',
            }).done(data => {
                const place = data.places[0];
                this.querySelector('input#lat').value = place.lat;
                this.querySelector('input#lng').value = place.lng;
                this.onInputUpdated();
            });
        };

        if (this.getAttribute('useGeolocation')) {
            navigator.geolocation.getCurrentPosition(
                pos => {
                    if (this.viewAdjusted) {
                        // user has used the map already, don't ruin it
                        return;
                    }
                    this.map.panTo([pos.coords.latitude, pos.coords.longitude]);
                },
                err => {
                    console.warn(`Failed to obtain user's location (Error ${err.code}, "${err.message}"), using the preconfigured default`);
                },
                { timeout: 5000 },
            );
        }
    }

    getElementById(id) {
        return this.querySelector('#' + id);
    }

    onInputUpdated() {
        const lat = this.querySelector('input#lat').value;
        const lng = this.querySelector('input#lng').value;
        this.map.panTo([lat, lng]);

        this.redrawCircle();

        // When a user manually edits coordinates/radius
        // we update the displayed map and the underlying query.
        this.querySelector('input#lat').addEventListener('input', this.onInputUpdated.bind(this));
        this.querySelector('input#lng').addEventListener('input', this.onInputUpdated.bind(this));
        this.querySelector('input#rad').addEventListener('input', this.onInputUpdated.bind(this));
        this.updateGeoQuery();
    }

    redrawCircle() {
        if (this.circle && this.useBboxSearch) {
            this.circle.removeFrom(this.map);
            this.circle = undefined;
        } else if (!this.useBboxSearch) {
            if (!this.circle) {
                this.circle = L.circle(this.defaultPosition, { radius: 120_000 });
                this.circle.addTo(this.map);
            }
            this.circle.setLatLng(this.map.getCenter());

            const match = this.querySelector('input#rad').value.match(/^(\d+)(k?m)?$/);
            if (match) {
                const [, amount, unit] = match;
                let meters = amount;
                if (unit === 'km') {
                    meters *= 1000;
                }
                this.circle.setRadius(meters);
            }
        }
    }

    updateGeoQuery() {
        if (this.useBboxSearch) {
            const bounds = this.map.getBounds();
            this.querySelector('input#geoquery').value = 'boundingbox:' + [
                bounds.getNorthWest().lat,
                bounds.getNorthWest().lng,
                bounds.getSouthEast().lat,
                bounds.getSouthEast().lng,
            ].join(',');
        } else {
            const lat = this.querySelector('input#lat').value;
            const lng = this.querySelector('input#lng').value;
            const rad = this.querySelector('input#rad').value;

            document.querySelector('input#geoquery').value = `lat:${lat} lng:${lng} distance:${rad}`;
        }
        this.viewAdjusted = true;
    }

    updateInputs() {
        const center = this.map.getCenter();
        this.querySelector('input#lat').value = center.lat;
        this.querySelector('input#lng').value = center.lng;
        this.updateGeoQuery();
    }
}

class GeoSearchResults extends HTMLElement {
    constructor() {
        super();
        this.mapContainer = document.createElement('div');
        this.mapContainer.setAttribute('class', 'geo_search_map');
        this.appendChild(this.mapContainer);
    }

    connectedCallback() {
        this.map = L.map(this.mapContainer).setView([48, 13], 13);
        const tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        }).addTo(this.map);
    }

    static get observedAttributes() {
        return ['entries'];
    }

    attributeChangedCallback(name, oldValue, newValue) {
        if (name === 'entries' && newValue != oldValue) {
            this.drawMarkers(JSON.parse(newValue));
        }
    }

    drawMarkers(entries) {
        const bounds = L.latLngBounds();
        const coordEntries = new Map();

        for (const value of entries.data) {
            const coordHash = value.coordinates.join(':');

            let entries = coordEntries.get(coordHash);
            if (!entries) {
                entries = [];
                coordEntries.set(coordHash, entries);
            }
            entries.push(value);

            bounds.extend(value['coordinates']);
        }
        if (bounds.isValid()) { // won't be if we have no results
            this.map.fitBounds(bounds);
        }

        for (const entries of coordEntries.values()) {
            const marker = L.marker(entries[0]['coordinates']).addTo(this.map);
            const content = entries.map((e, i) => `${i}. ${e.title}`).join('<br />');
            marker.bindPopup(content);
        }

        this.map.on('moveend', () => {
            this.dispatchEvent(new CustomEvent('map-moved', {
                bubbles: true,
                cancellable: true,
                detail: { center: this.map.getCenter(), bounds: this.map.getBounds() },
            }));
        });
    }
}

try {
    customElements.define('geosearch-form', GeoSearchForm);
    customElements.define('geosearch-results', GeoSearchResults);
} catch (err) {
    console.error("Error registering components:", err);
}
