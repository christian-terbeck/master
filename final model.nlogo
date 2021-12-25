; @model Optimizing Social Distance Keeping in Indoor Environments via a Public Display Navigation Support System
; @author Christian Terbeck <christian.terbeck@uni-muenster.de>
;
; @description This model simulates the movement of people in indoor environments while considering social forces.
;              Public displays are used to guide the people with the aim to reduce contacts between them.

;Todo:
; - Design interface
; - Improve visiting feature (people spawning at entrances, visiting for a certain amount of time, etc.)
; - Fix bugs (e.g. contact stamps)

extensions [csv gis]

globals [
  resource-path
  output-path
  output-ticks
  output-contacts
  output-critical-contacts
  output-unique-contacts
  time
  mean-speed
  mean-visiting-time
  stddev-speed
  flow-cum
  overall-contacts
  overall-contact-time
  unique-contacts
  critical-contacts
  contact-distance-values
  contact-distance
]

breed [peds ped]
peds-own [
  speedx
  speedy
  is-familiar?
  is-visiting?
  has-visited?
  origin
  destination
  has-reached-first-node?
  next-node
  last-node
  paths
  current-path
  number-of-unique-contacts
  number-of-contacts
  had-contact-with
  active-contacts
  active-contacts-periods
]

breed [nodes node]
nodes-own [
  is-origin?
  is-destination?
  has-public-display?
]

breed [circles circle]

; @method setup
; @description Performs the necessary steps to run the simulation

to setup
  clear-all
  reset-ticks

  set resource-path word "resources/" word scenario "/"

  if write-output? [
    set output-path word "output/" word scenario word "/" word format-date-time date-and-time ".csv"

    set output-ticks []
    set output-contacts []
    set output-critical-contacts []
    set output-unique-contacts []
  ]

  set-default-shape peds "person"
  set-default-shape circles "circle 2"

  set-environment
  set-nodes
  set-agents

  if show-logs? [
    print "- Setup complete, you may start the simulation now -"
  ]
end

; @method set-environment
; @description Sets up the environment and defines the fields

to set-environment
  gis:set-transformation (list min-pxcor max-pxcor min-pycor max-pycor) (list min-pxcor max-pxcor min-pycor max-pycor)

  if show-logs? [
    print word "Loading floor plan: " word resource-path "floorplan.png"
  ]

  import-pcolors word resource-path "floorplan.png"
end

; @method create-circle
; @description Creates a circle around a ped to display the contact radius on the interface

to create-circle
  hatch-circles 1 [
    set size contact-radius
    set color lput 20 extract-rgb color
    __set-line-thickness 0.5

    create-link-with myself [
      tie
      hide-link
    ]
  ]
end

; @method set-nodes
; @description Loads the nodes and their links from external sources and adds them to the world

to set-nodes
  if not file-exists? word resource-path "nodes.json" [
    error word "The required file " word resource-path "nodes.json is missing."
  ]

  if show-logs? [
    print word "Loading nodes from external source: " word resource-path "nodes.json"
  ]

  let json-nodes gis:load-dataset word resource-path "nodes.json"

  gis:create-turtles-from-points-manual json-nodes nodes [["ISORIGIN" "is-origin?"] ["ISDESTINATION" "is-destination?"] ["HASPUBLICDISPLAY" "has-public-display?"]] [
    set shape "circle"
    set color green

    if not show-paths? [
      set hidden? true
    ]

    if show-labels? [
      set label count nodes - 1
    ]
  ]

  ask nodes [
    ifelse is-origin? = "true" [
      set is-origin? true
    ] [
      set is-origin? false
    ]

    ifelse is-destination? = "true" [
      set is-destination? true

      set color red
    ] [
      set is-destination? false
    ]

    ifelse has-public-display? = "true" [
      set has-public-display? true

      set shape "computer server"
      set size 2
      set color gray
      set hidden? false
    ] [
      set has-public-display? false
    ]
  ]

  if not file-exists? word resource-path "node-links.csv" [
    error word "The required file " word resource-path "node-links.csv is missing."
  ]

  if show-logs? [
    print word "Loading node links from external source: " word resource-path "node-links.csv"
  ]

  file-open word resource-path "node-links.csv"

  while [not file-at-end?] [
    let arguments (csv:from-row file-read-line " ")
    link-nodes item 0 arguments item 1 arguments item 2 arguments
  ]

  file-close
end

; @method format-date-time
; @description Formats a given datetime string so that it can be used in a file name
; @param string datetime

to-report format-date-time [datetime]
  set datetime replace-item 2 datetime "-"
  set datetime replace-item 5 datetime "-"
  set datetime replace-item 8 datetime "-"
  set datetime replace-item 12 datetime "_"
  set datetime replace-item 15 datetime "_"

  report datetime
end

; @method string-to-list
; @description Transforms a string to a list
; @param string s

to-report string-to-list [s]
  report ifelse-value not empty? s [
    []
  ] [
    fput first s string-to-list but-first s
  ]
end

; @method set-agents
; @description Sets the agents/peds of the model

to set-agents
  repeat number-of-people [create-ped]

  ask n-of round (familiarity-rate * number-of-people) peds [
    set is-familiar? true
    set shape "person doctor"
    set color blue
  ]

  ask peds [
    init-paths self origin destination
    update-path self origin

    if show-circles? [
      create-circle
    ]

    if show-walking-paths? [
      pen-down
    ]
  ]
end

; @method create-ped
; @description Creates a new ped and sets its attributes

to create-ped
  let x 0
  let y 0
  let tmp-first-node nobody

  ask one-of nodes with [is-origin? = true] [
    set x pxcor
    set y pycor
    set tmp-first-node self
  ]

  create-peds 1 [
    set shape "person"
    set color cyan
    set xcor x + random-normal 0 0.2
    set ycor y + random-normal 0 0.2
    set is-familiar? false
    set is-visiting? true ;temporarily
    set has-visited? false
    set origin tmp-first-node
    set destination one-of nodes with [is-destination? = true]

    set had-contact-with []
    set active-contacts []
    set active-contacts-periods []
    set label-color black
  ]
end

; @method link-nodes
; @description Creates a directed or undirected link between two nodes
; @param int id1
; @param int id2
; @param bool is-two-way?

to link-nodes [id1 id2 is-two-way?]
  ask node id1 [
    ifelse is-two-way? [
      create-link-with node id2 [
        if not show-paths? [
          hide-link
        ]
      ]
    ] [
      create-link-to node id2 [
        if not show-paths? [
          hide-link
        ]
      ]
    ]
  ]
end

;Todo: What to do with this..?

to plot!
  set-current-plot "Speed"
  set-current-plot-pen "Mean"
  plotxy time mean-speed / ticks
  set-current-plot-pen "Stddev"
  plotxy time stddev-speed / ticks
  set-current-plot "Mean flow" set-plot-y-range 0 2
  set-current-plot-pen "Spatial"
  plotxy time (mean-speed / ticks * number-of-people / world-width / world-height)
  set-current-plot-pen "Temporal"
  plotxy time flow-cum / time / world-height
end

; @method init-paths
; @description Initializes the ped`s routing from one node to another
; @param ped k
; @param node node1
; @param node node2

to init-paths [k node1 node2]
  set origin node1
  set destination node2
  set next-node nobody
  set has-reached-first-node? false
  set last-node node1
  set paths []
  set current-path []
  set-paths self (list (list node1))
end

; @method update-path
; @description Updates the current path based on the ped`s familiarity and public display sensory (if applicable)
; @param ped k
; @param node n

to update-path [k n]
  let current-node-has-display? false

  ask n [
    set current-node-has-display? has-public-display?
  ]

  ifelse not is-familiar? and current-node-has-display? [
    let available-paths paths

    let adjacent-nodes []
    let has-detected-current-node? false

    foreach available-paths [path-nodes ->
      set has-detected-current-node? false

      foreach path-nodes [cur-node ->
        if has-detected-current-node? [
          if not member? cur-node adjacent-nodes [
            set adjacent-nodes lput cur-node adjacent-nodes
          ]

          set has-detected-current-node? false
        ]

        if cur-node = n [
          set has-detected-current-node? true
        ]
      ]
    ]

    let detected-people -1
    let least-crowded-adjacent-node nobody

    foreach adjacent-nodes [cur-node ->
      ask n [
        face cur-node

        if show-areas-of-awareness? [
          ask patches in-cone area-of-awareness angle-of-awareness with [not (pcolor = black)] [
            set pcolor yellow
          ]
        ]

        if detected-people = -1 or (detected-people > 0 and count peds in-cone area-of-awareness angle-of-awareness with [not (self = myself)] < detected-people) [
          set detected-people count peds in-cone area-of-awareness 70 with [not (self = myself)]
          set least-crowded-adjacent-node cur-node
        ]
      ]
    ]

    set has-detected-current-node? false
    let has-found-least-crowded-option? false

    foreach available-paths [path-nodes ->
      foreach path-nodes [cur-node ->
        if not has-found-least-crowded-option? and has-detected-current-node? and cur-node = least-crowded-adjacent-node [
          set current-path path-nodes
          set has-detected-current-node? false
          set has-found-least-crowded-option? true
        ]

        if cur-node = n [
          set has-detected-current-node? true
        ]
      ]
    ]
  ] [
    set current-path first paths
  ]

  set next-node item 1 current-path
end

; @method set-paths
; @description Sets the paths based on given starting nodes
; @param ped k
; @param list origin-nodes

to set-paths [k origin-nodes]
  let new-origin-nodes origin-nodes
  let destination-node destination

  foreach origin-nodes [i ->
    let reachable-nodes [out-link-neighbors] of last i

    ask reachable-nodes [
      let new-route i
      set new-route lput self new-route

      if not member? self i [
        ifelse self = destination-node [
          ask k [
            set paths lput new-route paths
          ]
        ] [
          set new-origin-nodes lput new-route new-origin-nodes
        ]
      ]
    ]

    let pos position i new-origin-nodes
    set new-origin-nodes remove-item pos new-origin-nodes
  ]

  if not empty? filter [i -> [is-destination?] of last i = false] new-origin-nodes [
    set-paths self new-origin-nodes
  ]
end

; @method trace-contacts
; @description Traces the contacts that occur between the peds

to trace-contacts
  ask peds [
    let has-contact-to []

    ask peds in-radius contact-radius with [not (self = myself)] [
      ifelse not member? [who] of myself active-contacts [
        set active-contacts lput [who] of myself active-contacts
        set active-contacts-periods lput 1 active-contacts-periods

        if show-logs? [
         print word self word " started contact with " myself
        ]
      ] [
        let pos position [who] of myself active-contacts
        let counter-value item pos active-contacts-periods
        set counter-value counter-value + 1
        set active-contacts-periods replace-item pos active-contacts-periods counter-value
      ]

      set has-contact-to lput [who] of self has-contact-to

      set contact-distance-values contact-distance-values + 1
      set contact-distance contact-distance + distance myself
    ]

    foreach active-contacts [x ->
      if not member? x has-contact-to [
        let pos position x active-contacts
        let counter-value item pos active-contacts-periods

        set active-contacts remove-item pos active-contacts
        set active-contacts-periods remove-item pos active-contacts-periods

        ifelse counter-value > contact-tolerance [
          set overall-contact-time overall-contact-time + counter-value
          set number-of-contacts number-of-contacts + 1
          set overall-contacts overall-contacts + 1

          if show-contacts? [
            stamp ;Todo: does not work completely; both agents are creating this stamp, but one would be enough
          ]

          if not (ped x = nobody) [
            ask ped x [
              if member? [who] of myself active-contacts [
                let pos2 position [who] of myself active-contacts

                if item pos2 active-contacts-periods != counter-value [
                  set active-contacts-periods replace-item pos2 active-contacts-periods counter-value
                ]
              ]
            ]

            if not member? x had-contact-with [
              set number-of-unique-contacts number-of-unique-contacts + 1
              set had-contact-with lput x had-contact-with

              set unique-contacts unique-contacts + 1
            ]
          ]

          if counter-value >= critical-period [
            set critical-contacts critical-contacts + 1
          ]

          if show-logs? [
            print word self word " lost contact to Person " word x word " after " word counter-value " ticks"
          ]
        ] [
          if show-logs? [
            print word "Contact between " word self word " and Person " word x word " with a duration of " word counter-value " ticks will not be considered due to its short duration"
          ]
        ]
      ]
    ]

    if show-labels? [
      set label number-of-contacts
    ]
  ]
end

; @method simulate
; @description Runs the simulation, which includes the movement of the agents, the event handling, output writing, etc.

to simulate
  set time precision (time + dt) 5 tick-advance 1
  trace-contacts

  ask peds [
    let hd towards next-node
    let h hd
    let repx 0
    let repy 0

    if not (speedx * speedy = 0) [
      set h atan speedx speedy
    ]

    ask peds in-cone (D) 120 with [not (self = myself)] [
      ifelse distance destination < D or distance next-node < D [
        set repx repx + A / 2 * exp((1 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h))
        set repy repy + A / 2 * exp((1 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h))
      ] [
        set repx repx + A * exp((1 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h))
        set repy repy + A * exp((1 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h))
      ]
    ]

    ask patches in-radius (D) with [pcolor = 0] [
      set repx repx + A * exp((1 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h))
      set repy repy + A * exp((1 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h))
    ]

    set speedx speedx + dt * (repx + (V0 * sin hd - speedx) / Tr)
    set speedy speedy + dt * (repy + (V0 * cos hd - speedy) / Tr)

    if distance next-node < D / 2 [
      set last-node next-node

      ifelse distance destination < D / 2 [
        if show-logs? [
          print word self " has reached its destination"
        ]

        ifelse is-visiting? and not has-visited? [
          init-paths self destination origin
          update-path self origin

          set has-visited? true
        ] [
          ask in-link-neighbors [
            die
          ]

          die
        ]
      ] [
        let pos (position next-node current-path) + 1

        ifelse not is-familiar? [
          set paths map [i -> but-first i] (filter [i -> item 1 i = next-node] paths)
          update-path self next-node
        ] [
          set next-node item pos current-path
        ]
      ]
    ]

    set xcor xcor + speedx * dt
    set ycor ycor + speedy * dt
  ]

  if write-output? and ticks mod output-steps = 0 [
    set output-ticks lput ticks output-ticks
    set output-contacts lput round (overall-contacts / 2) output-contacts
    set output-critical-contacts lput round (critical-contacts / 2) output-critical-contacts
    set output-unique-contacts lput round (unique-contacts / 2) output-unique-contacts
  ]

  if count peds < 1 or ticks = stop-at-ticks [
    if write-output? [
      csv:to-file output-path (list (output-ticks) (output-contacts) (output-critical-contacts) (output-unique-contacts))

      if show-logs? [
        print word "Created output file " output-path
      ]
    ]

    if show-logs? [
      print "- Simulation finished -"
    ]

    stop
  ]

  ;Todo remove or refactor things like mean speed, cum flow etc.

  if count peds > 1 [
    set mean-speed mean-speed + mean [sqrt(speedx ^ 2 + speedy ^ 2)] of peds
  ]

  if count peds > 1 [
    set stddev-speed stddev-speed + sqrt(variance [sqrt(speedx ^ 2 + speedy ^ 2)] of peds)
  ]

  ask peds with [(xcor > 0 and xcor - speedx * dt <= 0) or (xcor < 0 and xcor - speedx * dt >= 0) or (ycor > 0 and ycor - speedy * dt <= 0) or (ycor < 0 and ycor - speedy * dt >= 0)] [
    set flow-cum flow-cum + 1
  ]

  plot!
  update-plots
end
@#$#@#$#@
GRAPHICS-WINDOW
386
10
1091
716
-1
-1
17.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
0
0
1
Ticks
30.0

SLIDER
8
121
183
154
number-of-people
number-of-people
0
50
3.0
1
1
NIL
HORIZONTAL

BUTTON
187
72
242
118
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
247
72
302
118
NIL
Simulate
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1112
559
1467
679
Mean flow
Time
Flow
0.0
0.0
0.0
0.0
true
true
"" ""
PENS
"Spatial" 1.0 0 -11053225 true "" ""
"Temporal" 1.0 0 -11881837 true "" ""

PLOT
1111
437
1467
557
Speed
Time
Speed
0.0
0.0
0.0
0.0
true
true
"" ""
PENS
"Mean" 1.0 0 -11053225 true "" ""
"Stddev" 1.0 0 -11881837 true "" ""

SLIDER
190
657
365
690
V0
V0
0
5
1.0
1
1
NIL
HORIZONTAL

MONITOR
1111
388
1176
433
Time
time
17
1
11

MONITOR
1242
388
1315
433
Mean speed
mean [sqrt(speedx ^ 2 + speedy ^ 2)] of peds
5
1
11

MONITOR
1318
388
1398
433
Speed stddev
stddev-speed / ticks
5
1
11

MONITOR
1179
388
1239
433
Density
number-of-people / world-width / world-height
5
1
11

MONITOR
1401
388
1467
433
Flow
flow-cum / time / world-height
5
1
11

PLOT
1112
681
1299
801
Fundamental diagram
Density
Flow
0.0
0.0
0.0
0.0
true
false
"" ""
PENS
"default" 1.0 0 -11053225 true "" ""

PLOT
1302
681
1467
801
Speed stddev
Density
Stddev
0.0
0.0
0.0
0.7
true
false
"" ""
PENS
"default" 1.0 0 -11053225 true "" ""

SLIDER
12
657
187
690
dt
dt
0
1
0.46
.01
1
NIL
HORIZONTAL

SLIDER
190
693
365
726
D
D
0.1
5
3.3
.1
1
NIL
HORIZONTAL

BUTTON
308
72
363
119
NIL
Simulate
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
13
693
187
726
A
A
0
5
1.0
.1
1
NIL
HORIZONTAL

SLIDER
13
729
188
762
Tr
Tr
.1
2
0.5
.1
1
NIL
HORIZONTAL

SLIDER
187
121
363
154
familiarity-rate
familiarity-rate
0
1
0.0
.05
1
NIL
HORIZONTAL

SWITCH
12
551
186
584
show-logs?
show-logs?
1
1
-1000

SLIDER
10
348
182
381
contact-radius
contact-radius
0
10
3.6
0.1
1
NIL
HORIZONTAL

SLIDER
185
348
357
381
critical-period
critical-period
1
120
30.0
1
1
NIL
HORIZONTAL

SLIDER
10
384
182
417
contact-tolerance
contact-tolerance
0
10
5.0
1
1
NIL
HORIZONTAL

MONITOR
1110
11
1285
56
Number of contacts
overall-contacts / 2
0
1
11

MONITOR
1290
11
1466
56
Avg. number of contacts per person
overall-contacts / 2 / number-of-people
3
1
11

MONITOR
1110
59
1286
104
Unique contacts
unique-contacts / 2
0
1
11

MONITOR
1290
59
1466
104
Critical contacts
critical-contacts / 2
0
1
11

MONITOR
1110
107
1287
152
Avg. contact duration
overall-contact-time / overall-contacts
3
1
11

MONITOR
1291
107
1466
152
Avg. contact distance
contact-distance / contact-distance-values
3
1
11

PLOT
1111
158
1467
371
Contacts
ticks
contacts
0.0
100.0
0.0
50.0
true
true
"" ""
PENS
"overall-contacts" 1.0 0 -16777216 true "" "plot (overall-contacts / 2)"
"average-contacts" 1.0 0 -7500403 true "" "plot (overall-contacts /  number-of-people) * 2"
"critical-contacts" 1.0 0 -2674135 true "" "plot (critical-contacts / 2)"
"unique-contacts" 1.0 0 -955883 true "" "plot (unique-contacts / 2)"

SWITCH
185
385
357
418
show-circles?
show-circles?
0
1
-1000

SWITCH
12
587
187
620
show-labels?
show-labels?
0
1
-1000

SLIDER
186
245
358
278
area-of-awareness
area-of-awareness
0
20
10.0
1
1
NIL
HORIZONTAL

SWITCH
11
514
185
547
show-paths?
show-paths?
1
1
-1000

SWITCH
189
514
365
547
show-walking-paths?
show-walking-paths?
1
1
-1000

SWITCH
189
552
365
585
show-contacts?
show-contacts?
1
1
-1000

CHOOSER
8
72
184
117
scenario
scenario
"hospital" "airport" "testing-environment-1"
2

SWITCH
10
447
184
480
write-output?
write-output?
1
1
-1000

INPUTBOX
8
158
184
218
stop-at-ticks
100000.0
1
0
Number

SLIDER
8
245
183
278
angle-of-awareness
angle-of-awareness
0
90
30.0
1
1
NIL
HORIZONTAL

SWITCH
8
281
182
314
show-areas-of-awareness?
show-areas-of-awareness?
1
1
-1000

SLIDER
187
447
359
480
output-steps
output-steps
10
500
10.0
10
1
NIL
HORIZONTAL

TEXTBOX
9
10
370
44
Optimizing Social Distance Keeping in Indoor Environments via a Public Display Navigation Support System
14
0.0
1

TEXTBOX
9
55
159
73
Main setup
11
0.0
1

TEXTBOX
12
431
162
449
Output generation
11
0.0
1

TEXTBOX
10
228
160
246
Public Display settings
11
0.0
1

TEXTBOX
11
332
161
350
Contact settings
11
0.0
1

TEXTBOX
12
496
162
514
Additional options
11
0.0
1

TEXTBOX
15
640
310
668
Speed and Social Force (maybe just remove from interface)
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

ambulance
false
0
Rectangle -7500403 true true 30 90 210 195
Polygon -7500403 true true 296 190 296 150 259 134 244 104 210 105 210 190
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Circle -16777216 true false 69 174 42
Rectangle -1 true false 288 158 297 173
Rectangle -1184463 true false 289 180 298 172
Rectangle -2674135 true false 29 151 298 158
Line -16777216 false 210 90 210 195
Rectangle -16777216 true false 83 116 128 133
Rectangle -16777216 true false 153 111 176 134
Line -7500403 true 165 105 165 135
Rectangle -7500403 true true 14 186 33 195
Line -13345367 false 45 135 75 120
Line -13345367 false 75 135 45 120
Line -13345367 false 60 112 60 142

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

computer server
false
0
Rectangle -7500403 true true 75 30 225 270
Line -16777216 false 210 30 210 195
Line -16777216 false 90 30 90 195
Line -16777216 false 90 195 210 195
Rectangle -10899396 true false 184 34 200 40
Rectangle -10899396 true false 184 47 200 53
Rectangle -10899396 true false 184 63 200 69
Line -16777216 false 90 210 90 255
Line -16777216 false 105 210 105 255
Line -16777216 false 120 210 120 255
Line -16777216 false 135 210 135 255
Line -16777216 false 165 210 165 255
Line -16777216 false 180 210 180 255
Line -16777216 false 195 210 195 255
Line -16777216 false 210 210 210 255
Rectangle -7500403 true true 84 232 219 236
Rectangle -16777216 false false 101 172 112 184

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person business
false
0
Rectangle -1 true false 120 90 180 180
Polygon -13345367 true false 135 90 150 105 135 180 150 195 165 180 150 105 165 90
Polygon -7500403 true true 120 90 105 90 60 195 90 210 116 154 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 183 153 210 210 240 195 195 90 180 90 150 165
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 76 172 91
Line -16777216 false 172 90 161 94
Line -16777216 false 128 90 139 94
Polygon -13345367 true false 195 225 195 300 270 270 270 195
Rectangle -13791810 true false 180 225 195 300
Polygon -14835848 true false 180 226 195 226 270 196 255 196
Polygon -13345367 true false 209 202 209 216 244 202 243 188
Line -16777216 false 180 90 150 165
Line -16777216 false 120 90 150 165

person doctor
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -13345367 true false 135 90 150 105 135 135 150 150 165 135 150 105 165 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -1 true false 105 90 60 195 90 210 114 156 120 195 90 270 210 270 180 195 186 155 210 210 240 195 195 90 165 90 150 150 135 90
Line -16777216 false 150 148 150 270
Line -16777216 false 196 90 151 149
Line -16777216 false 104 90 149 149
Circle -1 true false 180 0 30
Line -16777216 false 180 15 120 15
Line -16777216 false 150 195 165 195
Line -16777216 false 150 240 165 240
Line -16777216 false 150 150 165 150

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
