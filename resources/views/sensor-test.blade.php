<div id="output"></div>

<script type="module">

// https://intel.github.io/generic-sensor-demos
// https://github.com/intel/generic-sensor-demos
// https://w3c.github.io/orientation-sensor/#relativeorientationsensor-interface

// import { RelativeOrientationSensor } from '../../js/sensors.js';
import { Gyroscope } from '../../js/sensors.js';

const sensor = new Gyroscope();

var x = 0;
var y = 0;
var z = 0;

sensor.start();

sensor.addEventListener('reading', () => {
    x += sensor.x ? sensor.x : 0;
    y += sensor.y ? sensor.y : 0;
    z += sensor.z ? sensor.z : 0;

    document.getElementById('output').innerHTML = 'X: ' + x + '<br>Y: ' + y + '<br>Z: ' + z;
});

console.log(sensor);
console.log(sensor.x);
console.log(sensor.y);
console.log(sensor.z);
console.log(sensor.timestamp);
/*const options = { frequency: 60, referenceFrame: 'device' };
const sensor = new RelativeOrientationSensor(options);

sensor.addEventListener('reading', () => {
    // model is a Three.js object instantiated elsewhere.
    // model.quaternion.fromArray(sensor.quaternion).inverse();
    // document.getElementById('output').innerHTML = sensor.quaternion;
});

sensor.addEventListener('error', error => {
    if (event.error.name == 'NotReadableError') {
        console.log("Sensor is not available.");
    }
});

sensor.start();

console.log(sensor.quaternion);*/
// console.log(Object.getOwnPropertyNames(sensor));
//document.getElementById('output').innerHTML = sensor.quaternion;

// window.ondeviceorientation = function(event) { console.log(event); };
// window.addEventListener('deviceorientation', function(event) { console.log(event); });

/*
const sensor = new RelativeOrientationSensor();
Promise.all([navigator.permissions.query({ name: "accelerometer" }),
             navigator.permissions.query({ name: "gyroscope" })])
       .then(results => {
            if (results.every(result => result.state === "granted")) {
                sensor.start();
                //...
            } else {
                console.log("No permissions to use RelativeOrientationSensor.");
            }
   });
*/

</script>
