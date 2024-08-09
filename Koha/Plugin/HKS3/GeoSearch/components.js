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
        this.map.fitBounds(bounds);

        for (const entries of coordEntries.values()) {
            const marker = L.marker(entries[0]['coordinates']).addTo(this.map);
            const content = entries.map((e, i) => `${i}. ${e.title}`).join('<br />');
            marker.bindPopup(content);
        }
    }
}

customElements.define('geosearch-results', GeoSearchResults);
