; @model Optimizing Social Distance Keeping in Indoor Environments via a Public Display Navigation Support System
; @author Christian Terbeck <christian.terbeck@uni-muenster.de>
;
; @description This model simulates the movement of people in indoor environments while considering social forces.
;              Public displays are used to guide the people with the aim to reduce contacts between them.

;Todo:
; - Sort paths by shortest distance (ASC)
; - Fix and finish testing environments
; - highlight starting/origin nodes
; - Improve visiting feature (people spawning at entrances, visiting for a certain amount of time, etc.)!!!
; - Fix bugs (e.g. directed links and undirected links in one scenario 2, contact stamps)
; - think of an idea to implement neighborhoods (moore and van neumann!!!)
; - implement UKM floorplan!
; - light and dark mode
; - use directed links between nodes??
; -

extensions [csv gis]

globals [
  interface-width
  resource-path
  output-path
  output-ticks
  output-contacts
  output-critical-contacts
  output-unique-contacts
  total-number-of-people
  total-number-of-familiar-people
  time
  level-switching-duration
  mean-visiting-time
  overall-contacts
  overall-contact-time
  unique-contacts
  critical-contacts
  contact-distance-values
  contact-distance
]

breed [peds ped]
peds-own [
  is-initialized?
  speedx
  speedy
  is-familiar?
  is-visiting?
  has-visited?
  is-waiting?
  waiting-time
  current-level
  level-switching-time
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
  peds-waiting-here
  level
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

; @method show-coordinate
; @description Helper function that prints the coordinate when clicking on the interface (when active)

to show-coordinate
  if mouse-down? and timer > .2 [
    reset-timer
    print word "Clicked at coordinate (" word round mouse-xcor word "/" word round mouse-ycor ")"
  ]
end

; @method set-environment
; @description Sets up the environment and defines the fields

to set-environment
  no-display

  set interface-width 80
  let dim-x 20
  let dim-y 20

  if scenario = "hospital" [
    set dim-x 40
    set dim-y 40
  ]

  if scenario = "airport" [
    set dim-x 80
    set dim-y 60
  ]

  if scenario = "testing-environment-1" or scenario = "testing-environment-2" [
    set dim-x 20
    set dim-y 20
  ]

  if scenario = "testing-environment-3" [
    set dim-x 30
    set dim-y 20
  ]

  if scenario = "testing-environment-4" [
    set dim-x 40
    set dim-y 40
  ]

  resize-world (dim-x * -1) dim-x (dim-y * -1) dim-y

  let field-size interface-width / (dim-x / 5)
  set-patch-size field-size

  set level-switching-duration 15

  gis:set-transformation (list min-pxcor max-pxcor min-pycor max-pycor) (list min-pxcor max-pxcor min-pycor max-pycor)

  if not file-exists? word resource-path "floorplan.jpg" and not file-exists? word resource-path "floorplan.png" [
    error word "The required file " word resource-path "floorplan.jpg/floorplan.png is missing."
  ]

  ifelse file-exists? word resource-path "floorplan.jpg" [
    if show-logs? [
      print word "Loading floor plan: " word resource-path "floorplan.jpg"
    ]

    import-pcolors word resource-path "floorplan.jpg"
  ] [
    if show-logs? [
      print word "Loading floor plan: " word resource-path "floorplan.png"
    ]

    import-pcolors word resource-path "floorplan.png"
  ]

  display
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
    set color gray
    set label-color black

    if not show-paths? [
      set hidden? true
    ]
  ]

  ask nodes [
    ifelse is-origin? = "true" [
      set is-origin? true

      set color green
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

    if show-labels? [
      ifelse use-stop-feature? [
        set label peds-waiting-here
      ] [
        set label [who] of self
      ]
    ]
  ]

  if not any? nodes with [is-origin?] or not any? nodes with [is-destination?] [
    error "At least one origin and one destination node have to be defined."
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
  repeat initial-number-of-people [
    create-ped
  ]

  ask n-of round (familiarity-rate * total-number-of-people) peds [
    make-familiar self
  ]

  ask peds [
    init-ped self
  ]
end

; @method create-ped
; @description Creates a new ped and sets its attributes

to create-ped
  let x 0
  let y 0
  let tmp-first-node nobody

  ask one-of nodes with [is-origin?] [
    set x pxcor
    set y pycor
    set tmp-first-node self
  ]

  create-peds 1 [
    set shape "person"
    set color cyan
    set xcor x + random-normal 0 0.2
    set ycor y + random-normal 0 0.2
    set is-initialized? false
    set is-familiar? false
    set is-visiting? true ;Todo: check this feature: does this only apply to the hospital scenario?
    set has-visited? false
    set is-waiting? false
    set origin tmp-first-node
    set destination one-of nodes with [is-destination? and not (self = tmp-first-node)]
    set current-level [level] of tmp-first-node

    set had-contact-with []
    set active-contacts []
    set active-contacts-periods []
    set label-color black
  ]

  set total-number-of-people total-number-of-people + 1
end

; @method init-ped
; @description Initializes the ped after creation

to init-ped [k]
  init-paths self origin destination
  update-path self origin

  if show-circles? [
    create-circle
  ]

  if show-walking-paths? [
    pen-down
  ]

  set is-initialized? true
end

; @method make-familiar
; @description "Make the ped familiar" with the building

to make-familiar [k]
  set is-familiar? true
  set shape "person doctor"
  set color blue

  set total-number-of-familiar-people total-number-of-familiar-people + 1
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
        if [level] of node id1 != [level] of node id2 [
          set color green
        ]

        if not show-paths? [
          hide-link
        ]
      ]
    ] [
      create-link-to node id2 [
        if [level] of node id1 != [level] of node id2 [
          set color green
        ]

        if not show-paths? [
          hide-link
        ]
      ]
    ]
  ]
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
  let number-of-peds-waiting 0

  ask n [
    set current-node-has-display? has-public-display?
    set number-of-peds-waiting peds-waiting-here
  ]

  ifelse not use-static-signage? and not is-familiar? and current-node-has-display? [
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
    let tmp-detected-people 0
    let least-crowded-adjacent-node nobody

    foreach adjacent-nodes [cur-node ->
      set tmp-detected-people 0

      ask n [
        face cur-node

        if show-areas-of-awareness? [
          ask patches in-cone area-of-awareness angle-of-awareness with [not (pcolor = black)] [
            set pcolor yellow
          ]
        ]

        set tmp-detected-people count peds in-cone area-of-awareness angle-of-awareness with [not (self = k)]

        if detected-people = -1 or (detected-people > 0 and tmp-detected-people < detected-people) [
          set detected-people tmp-detected-people
          set least-crowded-adjacent-node cur-node
        ]
      ]
    ]

    if use-stop-feature? [
      ifelse (not is-waiting? and detected-people > number-of-peds-waiting) or (is-waiting? and waiting-time < max-waiting-time and detected-people > number-of-peds-waiting - 1) [
        if not is-waiting? [
          set is-waiting? true
          set color orange

          ask n [
            set peds-waiting-here peds-waiting-here + 1

            if show-labels? [
              set label peds-waiting-here
            ]
          ]
        ]

        set waiting-time waiting-time + 1
      ] [
        if is-waiting? [
          set is-waiting? false
          set waiting-time 0
          set color cyan

          ask n [
            set peds-waiting-here peds-waiting-here - 1

            if show-labels? [
              set label peds-waiting-here
            ]
          ]
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
    if empty? paths [
      error word "No valid route for " word k word " detected (from node " word [who] of origin word " to node " word [who] of destination ")"
    ]

    set current-path first paths
  ]

  if not is-waiting? [
    set next-node item 1 current-path
  ]
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

; @method set-paths
; @description Hides the ped and its related agents
; @param ped k

to hide-me [k]
  hide-turtle

  ask in-link-neighbors [
    hide-turtle
  ]
end

; @method show-me
; @description Shows the ped and its related agents
; @param ped k

to show-me [k]
  show-turtle

  ask in-link-neighbors [
    show-turtle
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

  ask peds with [not (is-waiting?)] [
    let hd towards next-node
    let h hd
    let repx 0
    let repy 0

    if not (speedx * speedy = 0) [
      set h atan speedx speedy
    ]

    ;Todo: move social force to external report function

    ask peds in-cone (D) 120 with [not (self = myself)] [
      ifelse distance destination < D or distance next-node < D [
        set repx repx + A / 2 * exp((1 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h))
        set repy repy + A / 2 * exp((1 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h))
      ] [
        set repx repx + A * exp((1 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h))
        set repy repy + A * exp((1 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h))
      ]
    ]

    ;Todo: work on social force when it comes to black patches - maybe just prevent walking on black patches

;    ask patches in-radius (D) with [pcolor = 0] [
;      set repx repx + A * exp((1 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h))
;      set repy repy + A * exp((1 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h))
;    ]

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

        ifelse [level] of item pos current-path != current-level [
          ifelse level-switching-time < level-switching-duration [
            if not hidden? [
              hide-me self
            ]

            set level-switching-time level-switching-time + 1
          ] [
            set paths map [i -> but-first i] (filter [i -> item 1 i = next-node] paths)
            set next-node item pos current-path
            move-to next-node
            set current-level [level] of next-node
            set level-switching-time 0
            show-me self
          ]
        ] [
          ifelse not is-familiar? [
            set paths map [i -> but-first i] (filter [i -> item 1 i = next-node] paths)
            update-path self next-node
          ] [
            set next-node item pos current-path
          ]
        ]
      ]
    ]

    set xcor xcor + speedx * dt
    set ycor ycor + speedy * dt
  ]

  ask peds with [is-waiting?] [
    update-path self last-node
  ]

  if spawn-rate > 0 and ticks > 0 and ticks mod spawn-rate = 0 [
    create-ped

    ask peds with [not (is-initialized?)] [
      if familiarity-rate > 0 and ((total-number-of-familiar-people > 0 and total-number-of-familiar-people / total-number-of-people < familiarity-rate) or total-number-of-familiar-people < 1) [
        make-familiar self
      ]

      init-ped self
    ]
  ]

  if write-output? and ticks mod output-steps = 0 [
    set output-ticks lput ticks output-ticks
    set output-contacts lput round (overall-contacts / 2) output-contacts
    set output-critical-contacts lput round (critical-contacts / 2) output-critical-contacts
    set output-unique-contacts lput round (unique-contacts / 2) output-unique-contacts
  ]

  if (count peds < 1 and spawn-rate < 1) or ticks = stop-at-ticks [
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

  update-plots
end
@#$#@#$#@
GRAPHICS-WINDOW
380
10
1207
838
-1
-1
20.0
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
119
183
152
initial-number-of-people
initial-number-of-people
0
50
0.0
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

SLIDER
1400
459
1575
492
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
1223
387
1288
432
Time
time
17
1
11

MONITOR
1292
387
1352
432
Density
count peds / world-width / world-height
5
1
11

SLIDER
1222
459
1397
492
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
1400
495
1575
528
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
1223
495
1397
528
A
A
0
1
0.5
.1
1
NIL
HORIZONTAL

SLIDER
1223
531
1398
564
Tr
Tr
.1
2
1.3
.1
1
NIL
HORIZONTAL

SLIDER
8
154
184
187
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
11
581
185
614
show-logs?
show-logs?
1
1
-1000

SLIDER
9
380
181
413
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
184
380
356
413
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
9
416
181
449
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
1223
10
1398
55
Number of contacts
overall-contacts / 2
0
1
11

MONITOR
1403
10
1579
55
Avg. number of contacts per person
overall-contacts / 2 / total-number-of-people
3
1
11

MONITOR
1223
58
1399
103
Unique contacts
unique-contacts / 2
0
1
11

MONITOR
1403
58
1579
103
Critical contacts
critical-contacts / 2
0
1
11

MONITOR
1223
106
1400
151
Avg. contact duration
overall-contact-time / overall-contacts
3
1
11

MONITOR
1404
106
1579
151
Avg. contact distance
contact-distance / contact-distance-values
3
1
11

PLOT
1224
157
1580
370
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
"average-contacts" 1.0 0 -7500403 true "" "plot (overall-contacts /  total-number-of-people) * 2"
"critical-contacts" 1.0 0 -2674135 true "" "plot (critical-contacts / 2)"
"unique-contacts" 1.0 0 -955883 true "" "plot (unique-contacts / 2)"

SWITCH
184
417
356
450
show-circles?
show-circles?
0
1
-1000

SWITCH
11
617
186
650
show-labels?
show-labels?
0
1
-1000

SLIDER
186
248
358
281
area-of-awareness
area-of-awareness
0
20
15.0
1
1
NIL
HORIZONTAL

SWITCH
10
544
184
577
show-paths?
show-paths?
0
1
-1000

SWITCH
188
544
364
577
show-walking-paths?
show-walking-paths?
1
1
-1000

SWITCH
188
582
364
615
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
"hospital" "airport" "testing-environment-1" "testing-environment-2" "testing-environment-3" "testing-environment-4"
2

SWITCH
9
479
183
512
write-output?
write-output?
0
1
-1000

INPUTBOX
187
121
363
181
stop-at-ticks
1000000.0
1
0
Number

SLIDER
8
248
183
281
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
9
320
181
353
show-areas-of-awareness?
show-areas-of-awareness?
1
1
-1000

SLIDER
186
479
358
512
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
11
463
161
481
Output generation
11
0.0
1

TEXTBOX
10
231
160
249
Public Display settings
11
0.0
1

TEXTBOX
10
364
160
382
Contact settings
11
0.0
1

TEXTBOX
11
526
161
544
Additional options
11
0.0
1

TEXTBOX
1225
442
1520
470
Speed and Social Force (maybe just remove from interface)
11
0.0
1

SWITCH
9
284
182
317
use-stop-feature?
use-stop-feature?
1
1
-1000

SWITCH
186
320
359
353
use-static-signage?
use-static-signage?
1
1
-1000

SLIDER
186
284
358
317
max-waiting-time
max-waiting-time
0
50
50.0
1
1
NIL
HORIZONTAL

BUTTON
11
682
186
715
NIL
show-coordinate
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
188
617
364
650
use-dark-mode?
use-dark-mode?
1
1
-1000

TEXTBOX
14
665
164
683
Helper functions
11
0.0
1

SLIDER
8
189
184
222
spawn-rate
spawn-rate
0
100
50.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model simulates people in indoor envirionments being guided by public displays.
The displays show dynamic content and aim to guide the people to their destination with a minimum amount of contacts to other people.

## HOW IT WORKS

The people move towards their destination along a path and are also aware of each other. They keep some distance to other agents and follow the instructions of the public displays whenever they encounter them (if they are not familiar with the building). The detection of other agents around public displays is achieved by scanning the surrounding area everytime a person needs further instructions.

## HOW TO USE IT

To initialize the simulation, select a scenario, choose your preferences and click setup. By clicking simulate, the simulation runs automatically.

## THINGS TO NOTICE

When running the simulation note the movement of the people, their reaction if they encounter a public display and their behavior when close to other agents.

## THINGS TO TRY

Feel free to experiment with each input on the interface. There are many different options and additional features that can be explored.

## EXTENDING THE MODEL

This model can be further enhanced with more different type of people, different scenarios and more detailed interaction with the public displays.

## NETLOGO FEATURES

This model uses the netlogo csv and netlogo gis extensions. They do not have to be installed separately and come with the basic netlogo software.


## CREDITS AND REFERENCES

Model created by

Christian Terbeck
christian.terbeck@uni-muenster.de

More details of this model can be found in my master thesis "Optimizing Social Distance Keeping in Indoor Environments via a Public Display Navigation Support System"
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
