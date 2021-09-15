<div id="output"></div>

<script type="module">

// https://intel.github.io/generic-sensor-demos
// https://github.com/intel/generic-sensor-demos
// https://w3c.github.io/orientation-sensor/#relativeorientationsensor-interface

// import { RelativeOrientationSensor } from '../../js/sensors.js';
import { Gyroscope } from '../../js/sensors.js';

const sensor = new Gyroscope();

sensor.start();

sensor.addEventListener('reading', () => {
    document.getElementById('output').innerHTML = 'X: ' + sensor.x + '<br>Y: ' + sensor.y + '<br>Z: ' + sensor.z;
});

console.log(sensor);

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
