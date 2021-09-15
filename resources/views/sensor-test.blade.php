<div id="output"></div>

<script type="module">

// https://intel.github.io/generic-sensor-demos
// https://w3c.github.io/orientation-sensor/#relativeorientationsensor-interface

import { RelativeOrientationSensor } from '../../js/sensors.js';

const options = { frequency: 60, referenceFrame: 'device' };
const sensor = new RelativeOrientationSensor(options);

sensor.addEventListener('reading', () => {
  // model is a Three.js object instantiated elsewhere.
  model.quaternion.fromArray(sensor.quaternion).inverse();
});
sensor.addEventListener('error', error => {
  if (event.error.name == 'NotReadableError') {
    console.log("Sensor is not available.");
  }
});
sensor.start();

console.log(sensor);
document.getElementById('output').innerHTML = sensor;

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