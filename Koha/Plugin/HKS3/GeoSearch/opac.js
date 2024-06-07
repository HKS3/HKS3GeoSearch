const page = $('body').attr('ID');
if (page === 'results') {
    $(document).ready(function() {
        $(".main").prepend('<div id="geo_search_map"></div>');
        var map = L.map('geo_search_map').setView([48, 13], 13);
        var tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        }).addTo(map);

        var biblionumbers = [];
        $(".addtocart").each(function() {
            biblionumbers.push( $(this).attr("data-biblionumber") );
        });
        if (biblionumbers.length === 0) {
            return;
        }

        $(function(e) {
            var ajaxData = { 'bn': biblionumbers };
            $.ajax({
                url: '/api/v1/contrib/geo_search/biblionumbers',
                type: 'GET',
                dataType: 'json',
                data: ajaxData,
                traditional: true
            }).done(function(data) {
                var bounds = L.latLngBounds()
                $.each(data['data'], function( index, value ) {
                    var marker = L.marker(value['coordinates']).addTo(map);
                    marker.bindPopup(index+1 + '. ' + value['title'] );
                    bounds.extend(value['coordinates']);
                });
                map.fitBounds(bounds);
            }).error(function(data) {});
        });
    });
} else if (page == 'advsearch') {
    const geosearch =`<div class="col-sm-6 col-lg-3">
        <style>
        #geosearch input:invalid {
            border: red solid 3px;
        }
        </style>
        <div id="geosearch" class="advsearch_limit">
            <form method="get" action="/cgi-bin/koha/opac-search.pl">
              <fieldset>
                  <label>Geographic Search</label>
                  <div id="geo_search_map"></div>
                  <input type="hidden" name="advsearch" value="1" />
                  <input type="hidden" name="idx" value="geolocation" />
                  <input type="hidden" name="do" value="Search" />
                  <input id="geoquery" type="hidden" name="q" />
                  <input type="text" size="6" id="lat" name="lat" title="Enter Latitude" value="48">
                  <input type="text" size="6" id="lng" name="lng" title="Enter Longitude" value="13">
                  <input type="text" size="6" id="rad" name="distance" title="Enter Radius" value="120km" pattern="(\\d+)(k?m)?">
                  <div class="hint">Search for Lat/long/Radius</div>
                  <input type="submit" />
              </fieldset>
            </form>
        </div>
    </div>`;

    $("#advsearch_limits").append(geosearch);
    $(document).ready(function() {
        var map = L.map('geo_search_map').setView([48, 13], 5);
        var tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        }).addTo(map);

        let circle = L.circle([48, 13], { radius: 120_000 });
        circle.addTo(map);

        function updateGeoQuery() {
            const lat = document.querySelector('input#lat').value;
            const lng = document.querySelector('input#lng').value;
            const rad = document.querySelector('input#rad').value;

            document.querySelector('input#geoquery').value = `lat:${lat} lng:${lng} distance:${rad}`;
        }

        // Whenever a map is panned by the user
        // we instantly update the position of the displayed circle.
        // The coordinates in inputs do not get updated instantly, since that'd trigger a map movement as well.
        function onMapChanged() {
            const center = map.getCenter();
            circle.setLatLng(center);
        }
        map.on('move', onMapChanged);

        // Whenever a user stops messing with a map (releases a mouse button)
        // we update the input fields and the underlying query
        function updateInputs() {
            const center = map.getCenter();
            document.querySelector('input#lat').value = center.lat;
            document.querySelector('input#lng').value = center.lng;
            updateGeoQuery();
        }
        map.on('mouseup', updateInputs);

        // When a user manually edits coordinates/radius
        // we update the displayed map and the underlying query.
        function onInputUpdated() {
            const lat = document.querySelector('input#lat').value;
            const lng = document.querySelector('input#lng').value;
            map.panTo([lat, lng]);
            circle.setLatLng([lat, lng]);

            const match = document.querySelector('input#rad').value.match(/^(\d+)(k?m)?$/);
            if (match) {
                const [, amount, unit] = match;
                let meters = amount;
                if (unit === 'km') {
                    meters *= 1000;
                }
                circle.setRadius(meters);
            }

            updateGeoQuery();
        }
        document.querySelector('input#lat').addEventListener('input', onInputUpdated);
        document.querySelector('input#lng').addEventListener('input', onInputUpdated);
        document.querySelector('input#rad').addEventListener('input', onInputUpdated);
    });
}
