; @model Optimizing Social Distance Keeping in Indoor Environments via a Public Display Navigation Support System
; @author Christian Terbeck <christian.terbeck@uni-muenster.de>
;
; @description This model simulates the movement of people in indoor environments while considering social forces.
;              Public displays are used to guide the people with the aim to reduce contacts between them.

extensions [csv gis]

globals [
  interface-width
  scale
  dim-x
  dim-y
  resource-path
  cache-path-limit
  output-path
  output-ticks
  output-contacts
  output-critical-contacts
  output-unique-contacts
  total-number-of-visitors
  total-number-of-dynamic-signage-people
  time
  levels
  level-switching-duration
  overall-contacts
  overall-contact-time
  unique-contacts
  critical-contacts
  visitor-contacts
  staff-contacts
  visitor-staff-contacts
  no-staff-only-contacts
  arrival-contacts
  departure-contacts
  contact-distance-values
  contact-distance
  avg-contact-distance
  avg-contact-time
  scenario-has-one-way-paths?
  prevent-unnecessary-level-switches?
  last-spawn
  last-gate-open
  last-gate-node
]

breed [peds ped]
peds-own [
  is-initialized?
  has-moved?
  speedx
  speedy
  is-staff?
  uses-dynamic-signage?
  is-visiting?
  has-visited?
  visit-start
  visiting-time
  treatment-start
  treatment-time
  is-waiting?
  waiting-time
  waiting-tolerance
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
  created-at
  init-delay
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

links-own [
  is-restricted?
]

; @method setup
; @description Performs the necessary steps to run the simulation

to setup
  clear-all
  reset-ticks

  if mean-visiting-time > max-visiting-time [
    error "The mean visiting time cannot be greater then the max visiting time"
  ]

  set resource-path word "resources/" word scenario "/"

  if write-output? [
    set output-path word "output/" word scenario word "/" word format-date-time date-and-time ".csv"

    set output-ticks []
    set output-contacts []
    set output-critical-contacts []
    set output-unique-contacts []
  ]

  ifelse scenario = "airport" [
    set-default-shape peds "person business"
  ] [
    set-default-shape peds "person"
  ]

  set-default-shape circles "circle 2"

  set cache-path-limit 50

  set-environment
  set-nodes
  set-agents

  if show-logs? [
    print "- Setup complete, you may start the simulation now -"
  ]
end

; @method observe-agent
; @description Observe a random agent

to observe-agent
  if not (subject = nobody) and not is-ped? subject [
    reset-perspective
  ]

  ifelse subject = nobody [
    if count peds > 0 [
      ride one-of peds
    ]
  ] [
    reset-perspective
  ]
end

; @method observe-display
; @description Observe a random display

to observe-display
  if not (subject = nobody) and not is-node? subject [
    reset-perspective
  ]

  ifelse subject = nobody [
    if count nodes with [has-public-display?] > 0 [
      ride one-of nodes with [has-public-display?]
    ]
  ] [
    reset-perspective
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

  set interface-width 90

  if not file-exists? word resource-path "config.csv" [
    error word "Scenario configuration file " word resource-path "config.csv is missing"
  ]

  if show-logs? [
    print word "Loading scenario settings from " word resource-path "config.csv"
  ]

  file-open word resource-path "config.csv"

  while [not file-at-end?] [
    let arguments (csv:from-row file-read-line " ")

    ifelse length arguments = 2 [
      run (word "set " item 0 arguments word " " item 1 arguments)
    ] [
      if show-logs? [
        print "Skipped invalid or empty line in config.csv"
      ]
    ]
  ]

  file-close

  resize-world (dim-x * -1) dim-x (dim-y * -1) dim-y

  let field-size interface-width / (dim-x / 5)
  set-patch-size field-size

  set levels []
  set level-switching-duration 20

  if enable-gis-extension? and member? "6." netlogo-version [
    gis:set-transformation (list min-pxcor max-pxcor min-pycor max-pycor) (list min-pxcor max-pxcor min-pycor max-pycor)
  ]

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
    set size (contact-radius * 2) / scale
    set color lput 20 extract-rgb color
    __set-line-thickness 0.5

    create-link-from myself [
      tie
      hide-link
    ]
  ]
end

; @method transform-nodes
; @description Transforms the geojson nodes to csv files for backwards compatibility

to transform-nodes
  ifelse member? "6." netlogo-version [
    if not file-exists? word resource-path "nodes.json" [
      error word "The required file " word resource-path "nodes.json is missing."
    ]

    let csv-file word resource-path "nodes.csv"

    let json-nodes gis:load-dataset word resource-path "nodes.json"

    ask nodes [
      die
    ]

    ;gis:create-turtles-from-points-manual json-nodes nodes [["ISORIGIN" "is-origin?"] ["ISDESTINATION" "is-destination?"] ["HASPUBLICDISPLAY" "has-public-display?"]] []

    let nodes-data []
    let cur-node-data []

    foreach sort nodes [cur-node ->
      set cur-node-data []

      set cur-node-data lput [xcor] of cur-node cur-node-data
      set cur-node-data lput [ycor] of cur-node cur-node-data
      set cur-node-data lput [is-origin?] of cur-node cur-node-data
      set cur-node-data lput [is-destination?] of cur-node cur-node-data
      set cur-node-data lput [has-public-display?] of cur-node cur-node-data
      set cur-node-data lput [level] of cur-node cur-node-data

      set nodes-data lput cur-node-data nodes-data
    ]

    csv:to-file csv-file (nodes-data)

    if show-logs? [
      print "Transformation complete. Please setup the model again if you would like to do a simulation."
    ]
  ] [
    error "Transformation not possible (invalid NetLogo version)"
  ]
end

; @method set-nodes
; @description Loads the nodes and their links from external sources and adds them to the world

to set-nodes
  set scenario-has-one-way-paths? false
  set prevent-unnecessary-level-switches? true

  if not file-exists? word resource-path "nodes.json" [
    error word "The required file " word resource-path "nodes.json is missing."
  ]

  if show-logs? [
    print word "Loading nodes from external source: " word resource-path "nodes.json"
  ]

  ifelse enable-gis-extension? and member? "6." netlogo-version [
    let json-nodes gis:load-dataset word resource-path "nodes.json"

;    gis:create-turtles-from-points-manual json-nodes nodes [["ISORIGIN" "is-origin?"] ["ISDESTINATION" "is-destination?"] ["HASPUBLICDISPLAY" "has-public-display?"]] [
;      set shape "circle"
;      set color gray
;      set label-color black
;
;      if not show-paths? [
;        set hidden? true
;      ]
;
;      if not member? level levels [
;        set levels lput level levels
;      ]
;    ]
  ] [
    if show-logs? [
      print word "Attempting to load nodes from " word resource-path "nodes.csv as gis features are not supported."
    ]

    if not file-exists? word resource-path "nodes.csv" [
      error word "The required file " word resource-path "nodes.csv is missing."
    ]

    file-open word resource-path "nodes.csv"

    while [not file-at-end?] [
      let arguments (csv:from-row file-read-line ",")

      ifelse length arguments = 6 [
        create-nodes 1 [
          set xcor item 0 arguments
          set ycor item 1 arguments
          set is-origin? item 2 arguments
          set is-destination? item 3 arguments
          set has-public-display? item 4 arguments
          set level item 5 arguments

          set shape "circle"
          set color gray
          set label-color black

          if not show-paths? [
            set hidden? true
          ]

          if not member? level levels [
            set levels lput level levels
          ]
        ]
      ] [
        if show-logs? [
          print "Skipped invalid or empty line in nodes.csv"
        ]
      ]
    ]

    file-close
  ]

  ask nodes [
    ifelse patch-size < 10 [
      set size 10 / patch-size
    ] [
      set size 1
    ]

    ifelse is-origin? = "true" or is-origin? = true [
      set is-origin? true

      set color green
    ] [
      set is-origin? false
    ]

    ifelse is-destination? = "true" or is-destination? = true [
      set is-destination? true

      set color red
    ] [
      set is-destination? false
    ]

    ifelse has-public-display? = "true" or has-public-display? = true [
      set has-public-display? true

      set shape "computer server"
      set size size * 2
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

    ifelse length arguments = 4 [
      link-nodes item 0 arguments item 1 arguments item 2 arguments item 3 arguments

      if not item 2 arguments and not scenario-has-one-way-paths? [
        set scenario-has-one-way-paths? true
      ]
    ] [
      if show-logs? [
        print "Skipped invalid or empty line in node-links.csv"
      ]
    ]
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
  if scenario = "hospital" and staff-members-per-level > 0 [
    let delay 0

    repeat staff-members-per-level [
      foreach levels [x ->
        create-ped true true x nobody delay
        set delay delay + round (30 + random-normal 0 5)
      ]
    ]
  ]

  repeat initial-number-of-visitors [
    ifelse scenario = "airport" [
      create-ped false false 2 nobody 0
    ] [
      create-ped false false -1 nobody 0
    ]
  ]

  if count peds with [(not is-staff?)] > 0 [
    ask n-of round (dynamic-signage-rate * total-number-of-visitors) peds with [(not is-staff?)] [
      use-dynamic-signage self
    ]
  ]
end

; @method create-ped
; @param bool is-staff?
; @param int level
; @description Creates a new ped and sets its attributes

to create-ped [uses-only-dynamic-signage? is-staff-member? level-number origin-node delay-seconds]
  let x 0
  let y 0
  let tmp-first-node nobody

  ifelse origin-node = nobody [
    ifelse level-number > -1 [
      ifelse scenario = "hospital" [
        ask one-of nodes with [level = level-number and is-destination?] [
          set x pxcor
          set y pycor
          set tmp-first-node self
        ]
      ] [
        ask one-of nodes with [level = level-number and is-origin?] [
          set x pxcor
          set y pycor
          set tmp-first-node self
        ]
      ]
    ] [
      ask one-of nodes with [is-origin?] [
        set x pxcor
        set y pycor
        set tmp-first-node self
      ]
    ]
  ] [
    ask origin-node [
      set x pxcor
      set y pycor
      set tmp-first-node self
    ]
  ]

  create-peds 1 [
    set is-staff? is-staff-member?

    ifelse is-staff-member? [
      if scenario != "airport" [
        set shape "person doctor"
      ]

      set color gray
      set uses-dynamic-signage? false
    ] [
      ifelse scenario = "airport" [
        set shape "person business"
      ] [
        set shape "person"
      ]

      set color cyan
      set uses-dynamic-signage? uses-only-dynamic-signage?
    ]

    set size 2 / scale

    set xcor x + random-normal 0 0.2
    set ycor y + random-normal 0 0.2
    set is-initialized? false
    set created-at time
    set init-delay delay-seconds
    set hidden? true

    set has-moved? false

    ifelse not is-staff-member? and scenario != "airport" [
      set is-visiting? true
      set visiting-time mean-visiting-time + random-normal 0 5

      if visiting-time > max-visiting-time [
        set visiting-time max-visiting-time
      ]

      if visiting-time < 5 [
        set visiting-time 5
      ]

      set visiting-time visiting-time * 60
    ] [
      set is-visiting? false
      set treatment-time mean-treatment-time + random-normal 0 5

      if treatment-time < 2 [
        set treatment-time 2
      ]

      set treatment-time treatment-time * 60
    ]

    set has-visited? false
    set is-waiting? false
    set waiting-tolerance mean-waiting-tolerance + random-normal 0 30

    if waiting-tolerance < 10 [
      set waiting-tolerance 10
    ]

    set origin tmp-first-node
    set current-level [level] of tmp-first-node

    ifelse (is-staff? and not staff-switches-levels?) or scenario = "airport" [
      ifelse scenario = "hospital" and random 20 != 19 [
        let destination-nodes nodes with [is-destination? and not (self = tmp-first-node) and (level = [level] of tmp-first-node)]
        let closest-nodes min-n-of 2 destination-nodes [distance tmp-first-node]
        set destination one-of closest-nodes
      ] [
        set destination one-of nodes with [is-destination? and not (self = tmp-first-node) and (level = [level] of tmp-first-node)]
      ]
    ] [
      set destination one-of nodes with [is-destination? and not (self = tmp-first-node)]
    ]

    set had-contact-with []
    set active-contacts []
    set active-contacts-periods []
    set label-color black
  ]

  if not is-staff-member? [
    set total-number-of-visitors total-number-of-visitors + 1
  ]
end

; @method init-ped
; @description Initializes the ped after creation

to init-ped [k]
  init-paths self origin destination
  update-path self origin

  set hidden? false

  if show-circles? [
    create-circle
  ]

  if show-walking-paths? [
    pen-down
  ]

  set is-initialized? true
end

; @method use-dynamic-signage
; @description This ped will only follow dynamic signage from now on

to use-dynamic-signage [k]
  set uses-dynamic-signage? true
  set color blue

  set total-number-of-dynamic-signage-people total-number-of-dynamic-signage-people + 1
end

; @method link-nodes
; @description Creates a directed or undirected link between two nodes
; @param int id1
; @param int id2
; @param bool is-two-way?

to link-nodes [id1 id2 is-two-way? is-staff-only?]
  ask node id1 [
    create-link-to node id2 [
      if [level] of node id1 != [level] of node id2 [
        set color green
      ]

      ifelse is-staff-only? [
        set is-restricted? true
        set color red
      ] [
        set is-restricted? false
      ]

      if not show-paths? [
        hide-link
      ]
    ]
  ]

  if is-two-way? [
    ask node id2 [
      create-link-to node id1 [
        if [level] of node id1 != [level] of node id2 [
          set color green
        ]

        ifelse is-staff-only? [
          set is-restricted? true
          set color red
        ] [
          set is-restricted? false
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
  let path-count 0

  let path-file word resource-path word "paths/" word [who] of node1 word "-" word [who] of node2 "-a.csv"
  let path-file-2 word resource-path word "paths/" word [who] of node2 word "-" word [who] of node1 "-a.csv"

  if not is-staff? [
    ifelse not force-all-visitors-to-stick-to-one-ways? and not uses-dynamic-signage? [
      set path-file word resource-path word "paths/" word [who] of node1 word "-" word [who] of node2 "-r-s.csv"
      set path-file-2 word resource-path word "paths/" word [who] of node2 word "-" word [who] of node1 "-r-s.csv"
    ] [
      set path-file word resource-path word "paths/" word [who] of node1 word "-" word [who] of node2 "-r-d.csv"
      set path-file-2 word resource-path word "paths/" word [who] of node2 word "-" word [who] of node1 "-r-d.csv"
    ]
  ]

  ifelse file-exists? path-file [
    file-open path-file
    let tmp-nodes []
    let tmp-path []

    while [not file-at-end? and path-count < cache-path-limit] [
      set tmp-nodes (csv:from-row file-read-line ",")

      set tmp-path []

      foreach tmp-nodes [i ->
        set tmp-path lput node i tmp-path
      ]

      set paths lput tmp-path paths

      set path-count path-count + 1
    ]

    file-close

    if show-logs? [
      print word "Loaded paths from cached file " path-file
    ]
  ] [
    ifelse file-exists? path-file-2 and (is-staff? or not scenario-has-one-way-paths?) [
      file-open path-file-2
      let tmp-nodes []
      let tmp-path []
      let path-ids []
      let cur-path-ids []

      while [not file-at-end?] [
        set tmp-nodes (csv:from-row file-read-line ",")

        set tmp-path []
        set cur-path-ids []

        foreach tmp-nodes [i ->
          set tmp-path lput node i tmp-path
          set cur-path-ids lput i cur-path-ids
        ]

        set paths lput reverse tmp-path paths
        set path-ids lput reverse cur-path-ids path-ids
      ]

      file-close

      csv:to-file path-file (path-ids)
    ] [
      if show-logs? [
        print word "Route from " word node1 word " to " word node2 " could not be created from cache. Starting to detect paths now."
      ]

      set-paths self (list (list node1))
      sort-paths self

      let path-ids []
      let cur-path-ids []

      foreach paths [i ->
        set cur-path-ids []

        foreach i [j ->
          set cur-path-ids lput [who] of j cur-path-ids
        ]

        set path-ids lput cur-path-ids path-ids
      ]

      csv:to-file path-file (path-ids)
    ]

    if show-logs? [
      print word "Created path file " path-file
    ]
  ]
end

; @method update-path
; @description Updates the current path based on the ped`s signage preferences and public display sensory (if applicable)
; @param ped k
; @param node n

to update-path [k n]
  let current-node-has-display? false
  let number-of-peds-waiting 0

  ask n [
    set current-node-has-display? has-public-display?
    set number-of-peds-waiting peds-waiting-here
  ]

  ifelse not use-static-signage? and uses-dynamic-signage? and not is-staff? and current-node-has-display? [
    let available-paths paths

    let adjacent-nodes []
    let adjacent-displays []
    let nodes-before-adjacent-displays []
    let has-detected-current-node? false
    let has-added-adjacent-node? false
    let has-added-adjacent-display? false
    let last-checked-node nobody

    foreach available-paths [path-nodes ->
      set has-detected-current-node? false
      set has-added-adjacent-node? false
      set has-added-adjacent-display? false
      set last-checked-node nobody

      foreach path-nodes [cur-node ->
        if has-detected-current-node? [
          if not has-added-adjacent-node? and not member? cur-node adjacent-nodes [
            set adjacent-nodes lput cur-node adjacent-nodes
            set has-added-adjacent-node? true
          ]

          set has-detected-current-node? false
        ]

        if has-added-adjacent-node? and not has-added-adjacent-display? and [has-public-display?] of cur-node [
          set adjacent-displays lput cur-node adjacent-displays
          set nodes-before-adjacent-displays lput last-checked-node nodes-before-adjacent-displays
          set has-added-adjacent-display? true
        ]

        if cur-node = n [
          set has-detected-current-node? true
        ]

        set last-checked-node cur-node
      ]

      if length adjacent-nodes > length adjacent-displays [
        set adjacent-displays lput nobody adjacent-displays
        set nodes-before-adjacent-displays lput last-checked-node nodes-before-adjacent-displays
      ]
    ]

    let detected-people -1
    let tmp-detected-people 0
    let least-crowded-adjacent-node nobody
    let loop-index 0
    let people-at-adjacent-display 0

    foreach adjacent-nodes [cur-node ->
      set tmp-detected-people 0
      set people-at-adjacent-display 0

      ask n [
        face cur-node

        if show-areas-of-awareness? [
          ask patches in-cone (area-of-awareness / scale) angle-of-awareness with [pcolor > 9] [
            set pcolor 58
          ]
        ]

        ifelse scan-movement-directions? [
          set tmp-detected-people (count peds in-cone (area-of-awareness / scale) angle-of-awareness with [not (self = k) and next-node = n and not (hidden?)]) * 2 + (count peds in-cone (area-of-awareness / scale) angle-of-awareness with [not (self = k) and next-node != n and not (hidden?)])
        ] [
          set tmp-detected-people count peds in-cone (area-of-awareness / scale) angle-of-awareness with [not (self = k) and not (hidden?)]
        ]

        if item loop-index adjacent-displays != nobody [
          ask item loop-index adjacent-displays [
            set people-at-adjacent-display peds-waiting-here
          ]

          if item loop-index nodes-before-adjacent-displays != nobody [
            face item loop-index nodes-before-adjacent-displays

            ifelse scan-movement-directions? [
              set people-at-adjacent-display people-at-adjacent-display + count peds in-cone (area-of-awareness / scale) angle-of-awareness with [next-node = item loop-index nodes-before-adjacent-displays]
            ] [
              set people-at-adjacent-display people-at-adjacent-display + count peds in-cone (area-of-awareness / scale) angle-of-awareness
            ]
          ]
        ]

        if consider-people-at-adjacent-displays? and people-at-adjacent-display > 0 [
          set tmp-detected-people tmp-detected-people + people-at-adjacent-display
        ]

        if detected-people = -1 or (detected-people > 0 and tmp-detected-people < detected-people) [
          set detected-people tmp-detected-people
          set least-crowded-adjacent-node cur-node
        ]

        if show-areas-of-awareness? [
          ask patches in-cone (area-of-awareness / scale) angle-of-awareness with [pcolor = 58] [
            set pcolor 9.9
          ]
        ]
      ]

      set loop-index loop-index + 1
    ]

    if use-stop-feature? [
      ifelse (not is-waiting? and detected-people > number-of-peds-waiting) or (is-waiting? and waiting-time < waiting-tolerance and detected-people > number-of-peds-waiting - 1) [
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

        set waiting-time precision (waiting-time + dt) 5
      ] [
        if is-waiting? [
          set is-waiting? false
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
    if waiting-time > 0 [
      set waiting-time precision (waiting-time - dt) 5

      if waiting-time < 0 [
        set waiting-time 0
      ]
    ]

    set next-node item 1 current-path
  ]
end

; @method set-paths
; @description Sets the paths based on given starting nodes
; @param ped k
; @param list origin-nodes

to set-paths [k origin-nodes]
  let new-origin-nodes origin-nodes
  let origin-node origin
  let destination-node destination

  foreach origin-nodes [i ->
    let connected-links [my-links] of last i

    if not is-staff? [
      ifelse not uses-dynamic-signage? [
        set connected-links [my-links with [not is-restricted?]] of last i
      ] [
        set connected-links [my-out-links with [not is-restricted?]] of last i
      ]
    ]

    let reachable-nodes []

    ask connected-links [
      ask both-ends [
        if [who] of self != [who] of last i [
          if not prevent-unnecessary-level-switches? or ([level] of origin-node != [level] of destination-node) or (prevent-unnecessary-level-switches? and [level] of origin-node = [level] of destination-node and [level] of self = [level] of destination-node) [
            set reachable-nodes lput self reachable-nodes
          ]
        ]
      ]
    ]

    foreach reachable-nodes [j ->
      let new-route i
      set new-route lput j new-route

      if not member? j i [
        ifelse j = destination-node [
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

  if not empty? filter [i -> [not (self = destination-node)] of last i] new-origin-nodes [
    set-paths self new-origin-nodes
  ]
end

; @method sort-paths
; @description Sorts the agent`s paths by distance
; @param ped k

to sort-paths [k]
  let sorted-paths []
  let cur-paths paths
  let distances []
  let path-distance 0
  let cur-last-node nobody
  let node-distance 0

  foreach cur-paths [i ->
    set path-distance 0
    set cur-last-node nobody
    set node-distance 0

    foreach i [j ->
      if cur-last-node != nobody [
        ask j [
          set node-distance distance cur-last-node
        ]

        set path-distance path-distance + node-distance
      ]

     set cur-last-node j
    ]

    set sorted-paths lput i sorted-paths
    set distances lput path-distance distances
  ]

  set path-distance 0
  let counter 0
  let tmp-distance 0
  let tmp-path []
  let is-sorted? false

  while [not (is-sorted?)] [
    set counter 0
    set is-sorted? true

    foreach distances [i ->
      if counter > 0 and i < path-distance [
        set tmp-distance i
        set tmp-path item counter sorted-paths

        set distances replace-item counter distances item (counter - 1) distances
        set sorted-paths replace-item counter sorted-paths item (counter - 1) sorted-paths

        set distances replace-item (counter - 1) distances tmp-distance
        set sorted-paths replace-item (counter - 1) sorted-paths tmp-path

        set is-sorted? false
      ]

      set path-distance i
      set counter counter + 1
    ]
  ]

  set paths sorted-paths
end

; @method hide-me
; @description Hides the ped and its related agents
; @param ped k

to hide-me [k]
  hide-turtle

  ask in-link-neighbors [
    hide-turtle
  ]

  ask out-link-neighbors [
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

  ask out-link-neighbors [
    show-turtle
  ]
end

; @method trace-contacts
; @description Traces the contacts that occur between the peds

to trace-contacts
  ask peds with [not (hidden?)] [
    let has-contact-to []

    ask peds in-radius (contact-radius / scale) with [not (self = myself) and not (hidden?)] [
      if not member? [who] of myself active-contacts [
        set active-contacts lput [who] of myself active-contacts
        set active-contacts-periods lput time active-contacts-periods

        if show-logs? [
          print word self word " started contact with " myself
        ]
      ]

      set has-contact-to lput [who] of self has-contact-to

      set contact-distance-values contact-distance-values + 1
      set contact-distance contact-distance + (distance myself * scale)
      set avg-contact-distance contact-distance / contact-distance-values
    ]

    foreach active-contacts [x ->
      if not member? x has-contact-to [
        let pos position x active-contacts
        let contact-start item pos active-contacts-periods
        let contact-duration time - contact-start

        set active-contacts remove-item pos active-contacts
        set active-contacts-periods remove-item pos active-contacts-periods

        ifelse contact-duration > contact-tolerance [
          set overall-contact-time overall-contact-time + contact-duration
          set number-of-contacts number-of-contacts + 1
          set overall-contacts overall-contacts + 1
          set avg-contact-time overall-contact-time / overall-contacts

          if show-contacts? [
            stamp
          ]

          if not (ped x = nobody) [
            ask ped x [
              if member? [who] of myself active-contacts [
                let pos2 position [who] of myself active-contacts

                if item pos2 active-contacts-periods != contact-start [
                  set active-contacts-periods replace-item pos2 active-contacts-periods contact-start
                ]
              ]
            ]

            if not member? x had-contact-with [
              set number-of-unique-contacts number-of-unique-contacts + 1
              set had-contact-with lput x had-contact-with

              set unique-contacts unique-contacts + 1
            ]
          ]

          if contact-duration >= (critical-period * 60) [
            set critical-contacts critical-contacts + 1
          ]

          ifelse is-staff? and (ped x != nobody and [is-staff?] of ped x = true) [
            set staff-contacts staff-contacts + 1
          ] [
            ifelse not is-staff? and (ped x = nobody or [is-staff?] of ped x = false) [
              set visitor-contacts visitor-contacts + 1
            ] [
              set visitor-staff-contacts visitor-staff-contacts + 1
            ]

            set no-staff-only-contacts no-staff-only-contacts + 1

            if scenario = "airport" [
              ifelse current-level = 1 [
                set arrival-contacts arrival-contacts + 1
              ] [
                set departure-contacts departure-contacts + 1
              ]
            ]
          ]

          if show-logs? [
            print word self word " lost contact to Person " word x word " after " word contact-duration " seconds"
          ]
        ] [
          if show-logs? [
            print word "Contact between " word self word " and Person " word x word " with a duration of " word contact-duration " seconds will not be considered due to its short duration"
          ]
        ]
      ]
    ]

    if show-labels? [
      set label number-of-contacts
    ]
  ]
end

; @method move
; @description Moves the ped
; @param ped k

to move [k]
  let hd 0

  carefully [
    set hd towards next-node
  ] [
    if show-logs? [
      print word "Skipped heading calculation at " word next-node word " as " word self " does not seem to change direction"
    ]
  ]

  let h hd
  let repx 0
  let repy 0

  if not (speedx * speedy = 0) [
    set h atan speedx speedy
  ]

  carefully [
    ask peds in-radius (D / scale) with [not (self = myself) and is-initialized? and not (hidden?)] [
      ifelse distance destination < (D / scale) or distance next-node < (D / scale) [
        set repx repx + A / 2 * exp((1 - distance myself) / (D / scale)) * sin(towards myself) * (1 - cos(towards myself - h))
        set repy repy + A / 2 * exp((1 - distance myself) / (D / scale)) * cos(towards myself) * (1 - cos(towards myself - h))
      ] [
        set repx repx + A * exp((1 - distance myself) / (D / scale)) * sin(towards myself) * (1 - cos(towards myself - h))
        set repy repy + A * exp((1 - distance myself) / (D / scale)) * cos(towards myself) * (1 - cos(towards myself - h))
      ]
    ]
  ] [
    if show-logs? [
      print word k " cannot keep distance to another ped this tick (social force may be too low)"
    ]
  ]

  ask patches in-radius ((D / scale) / 2) with [pcolor < 8] [
    set repx repx + (A * exp((1 - distance myself) / (D / scale)) * sin(towards myself) * (1 - cos(towards myself - h))) / 5
    set repy repy + (A * exp((1 - distance myself) / (D / scale)) * cos(towards myself) * (1 - cos(towards myself - h))) / 5
  ]

  set speedx speedx + dt * (repx + (V0 * sin hd - speedx) / Tr)
  set speedy speedy + dt * (repy + (V0 * cos hd - speedy) / Tr)

  if distance next-node < D / 2 or not has-moved? [
    if distance next-node < D / 2 [
      set last-node next-node
    ]

    ifelse distance destination < D / 2 [
      ifelse is-staff? [
        if not hidden? [
            hide-me self

            if show-logs? [
              print word self " has started patient treatment"
            ]
          ]

          ifelse treatment-start = 0 [
            set treatment-start time
          ] [
            if treatment-time - (time - treatment-start) < 0 [
              if show-logs? [
                print word self word " has ended the patient treatment after " word round treatment-time " seconds"
              ]

              set treatment-start 0
              set treatment-time mean-treatment-time + random-normal 0 5

              if treatment-time < 2 [
                set treatment-time 2
              ]

              set treatment-time treatment-time * 60

              let cur-destination destination
              let new-destination nobody

              ifelse random 20 != 19 [
                let destination-nodes nodes with [is-destination? and not (self = cur-destination) and (level = [level] of cur-destination)]
                let closest-nodes min-n-of 2 destination-nodes [distance cur-destination]
                set new-destination one-of closest-nodes
              ] [
                set new-destination one-of nodes with [is-destination? and not (self = cur-destination) and (level = [level] of cur-destination)]
              ]

              init-paths self destination new-destination
              update-path self origin

              show-me self
            ]
          ]
      ] [
        ifelse is-visiting? and not has-visited? [
          if not hidden? [
            hide-me self

            if show-logs? [
              print word self " has started its visit"
            ]
          ]

          ifelse visit-start = 0 [
            set visit-start time
          ] [
            if visiting-time - (time - visit-start) < 0 [
              if show-logs? [
                print word self word " has ended their visit after " word round visiting-time " seconds"
              ]

              init-paths self destination origin
              update-path self origin

              set has-visited? true
              show-me self
            ]
          ]
        ] [
          if show-logs? [
            print word self " has reached its final destination and was removed from the simulation"
          ]

          ask in-link-neighbors [
            die
          ]

          ask out-link-neighbors [
            hide-turtle
          ]

          die
        ]
      ]
    ] [
      let pos (position next-node current-path) + 1

      ifelse length current-path > pos and [level] of item pos current-path != current-level [
        ifelse level-switching-time = 0 [
          if not hidden? [
            hide-me self
          ]

          set level-switching-time time
        ] [
          if (time - level-switching-time) > level-switching-duration [
            set paths map [i -> but-first i] (filter [i -> item 1 i = next-node] paths)
            set next-node item pos current-path
            move-to next-node
            set current-level [level] of next-node
            set level-switching-time 0
            show-me self
          ]
        ]
      ] [
        if has-moved? [
          ifelse uses-dynamic-signage? [
            set paths map [i -> but-first i] (filter [i -> item 1 i = next-node] paths)
            update-path self next-node
          ] [
            set next-node item pos current-path
          ]
        ]
      ]
    ]
  ]

  carefully [
    set xcor xcor + speedx * dt
    set ycor ycor + speedy * dt
  ] [
    if show-logs? [
      print word self " cannot move beyond the world`s edge"
    ]
  ]

  if not has-moved? [
    set has-moved? true
  ]
end

; @method simulate
; @description Runs the simulation, which includes the movement of the agents, the event handling, output writing, etc.

to simulate
  set time precision (time + dt) 5
  tick-advance 1

  trace-contacts

  ask peds [
    ifelse not is-initialized? [
      if (init-delay < 1) or ((time - created-at) > init-delay) [
        if dynamic-signage-rate > 0 and ((total-number-of-dynamic-signage-people > 0 and total-number-of-visitors > 0 and total-number-of-dynamic-signage-people / total-number-of-visitors < dynamic-signage-rate) or total-number-of-dynamic-signage-people < 1) [
          use-dynamic-signage self
        ]

        init-ped self
      ]
    ] [
      ifelse is-waiting? [
        update-path self last-node
      ] [
        move self
      ]
    ]
  ]

  if spawn-rate > 0 and ticks > 0 and (time - last-spawn) > spawn-rate and count peds < max-capacity [
    set last-spawn time

    ifelse scenario = "airport" [
      create-ped false false 2 nobody 0
    ] [
      ifelse scenario = "hospital" and random 20 != 10 [
        create-ped false false -1 node 88 0
      ] [
        create-ped false false -1 nobody 0
      ]
    ]
  ]

  if scenario = "airport" and ticks > 0 and (time - last-gate-open) > (gate-open-period * 60) and count peds < max-capacity [
    set last-gate-open time
    let passenger-amount round (mean-passenger-number + random-normal 0 5)
    let gate-node one-of nodes with [level = 1 and is-origin? and not (self = last-gate-node)]
    set last-gate-node gate-node

    if passenger-amount < 10 [
      set passenger-amount 10
    ]

    let delay 0

    repeat passenger-amount [
      create-ped false false 1 gate-node delay
      set delay delay + round (7 + random-normal 0 2)
    ]

    if show-logs? [
      print word passenger-amount word " passengers have arrived at arrival gate " [who] of gate-node
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
384
10
1314
941
-1
-1
22.5
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
120
185
153
initial-number-of-visitors
initial-number-of-visitors
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
1581
543
1756
576
V0
V0
0
5
1.2
0.1
1
NIL
HORIZONTAL

MONITOR
1699
12
1754
57
Time (s)
time
0
1
11

MONITOR
1644
12
1695
57
Density
count peds with [not (hidden?)] / world-width / world-height
3
1
11

SLIDER
1403
543
1578
576
dt
dt
0
1
1.0
.01
1
NIL
HORIZONTAL

SLIDER
1581
579
1756
612
D
D
0.1
5
2.0
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
1404
579
1578
612
A
A
0
5
2.0
.1
1
NIL
HORIZONTAL

SLIDER
1404
615
1579
648
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
187
156
363
189
dynamic-signage-rate
dynamic-signage-rate
0
1
1.0
.05
1
NIL
HORIZONTAL

SWITCH
13
751
187
784
show-logs?
show-logs?
1
1
-1000

SLIDER
13
615
185
648
contact-radius
contact-radius
0
3
1.5
0.1
1
meters
HORIZONTAL

SLIDER
188
615
361
648
critical-period
critical-period
0
15
15.0
1
1
minutes
HORIZONTAL

SLIDER
13
651
185
684
contact-tolerance
contact-tolerance
0
10
2.0
1
1
seconds
HORIZONTAL

MONITOR
1399
60
1574
105
Number of contacts
overall-contacts / 2
0
1
11

MONITOR
1579
60
1755
105
Avg. number of contacts per person
overall-contacts / 2 / (total-number-of-visitors + count peds with [is-staff?])
3
1
11

MONITOR
1399
108
1574
153
Unique contacts
unique-contacts / 2
0
1
11

MONITOR
1580
108
1756
153
Critical contacts
critical-contacts / 2
0
1
11

MONITOR
1401
253
1578
298
Avg. contact duration (s)
avg-contact-time
3
1
11

MONITOR
1582
253
1757
298
Avg. contact distance (m)
avg-contact-distance
3
1
11

PLOT
1402
304
1758
517
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
"average-contacts" 1.0 0 -7500403 true "" "plot overall-contacts / 2 / (total-number-of-visitors + count peds with [is-staff?])"
"critical-contacts" 1.0 0 -2674135 true "" "plot (critical-contacts / 2)"
"unique-contacts" 1.0 0 -955883 true "" "plot (unique-contacts / 2)"
"visitor-contacts" 1.0 0 -6459832 true "" "plot(visitor-contacts / 2)"

SWITCH
189
652
360
685
show-circles?
show-circles?
1
1
-1000

SWITCH
13
787
188
820
show-labels?
show-labels?
1
1
-1000

SLIDER
13
413
186
446
area-of-awareness
area-of-awareness
1
50
10.0
0.5
1
meters
HORIZONTAL

SWITCH
12
714
186
747
show-paths?
show-paths?
1
1
-1000

SWITCH
189
714
360
747
show-walking-paths?
show-walking-paths?
1
1
-1000

SWITCH
189
752
360
785
show-contacts?
show-contacts?
1
1
-1000

CHOOSER
8
72
187
117
scenario
scenario
"hospital" "airport" "testing-environment-1" "testing-environment-2" "testing-environment-3" "testing-environment-4" "testing-environment-5" "testing-environment-6" "testing-environment-7" "testing-environment-8" "testing-environment-9" "testing-environment-10"
2

SWITCH
1407
806
1581
839
write-output?
write-output?
0
1
-1000

INPUTBOX
1582
710
1755
770
stop-at-ticks
0.0
1
0
Number

SLIDER
190
413
364
446
angle-of-awareness
angle-of-awareness
0
90
15.0
1
1
degrees
HORIZONTAL

SWITCH
13
484
185
517
show-areas-of-awareness?
show-areas-of-awareness?
0
1
-1000

SLIDER
1584
806
1756
839
output-steps
output-steps
10
1000
1000.0
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
1409
790
1559
808
Output generation
11
0.0
1

TEXTBOX
14
395
164
413
Public Display settings
11
0.0
1

TEXTBOX
14
599
164
617
Contact settings
11
0.0
1

TEXTBOX
13
696
163
714
Additional options
11
0.0
1

TEXTBOX
1406
526
1701
554
Speed and social force settings
11
0.0
1

SWITCH
13
448
186
481
use-stop-feature?
use-stop-feature?
1
1
-1000

SWITCH
190
484
363
517
use-static-signage?
use-static-signage?
1
1
-1000

SLIDER
190
449
364
482
mean-waiting-tolerance
mean-waiting-tolerance
0
1800
500.0
10
1
seconds
HORIZONTAL

BUTTON
1406
710
1579
743
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

TEXTBOX
1406
659
1556
677
Helper functions
11
0.0
1

SLIDER
8
156
183
189
spawn-rate
spawn-rate
0
1000
60.0
1
1
seconds
HORIZONTAL

SLIDER
187
120
363
153
max-capacity
max-capacity
0
2000
2000.0
1
1
visitors
HORIZONTAL

MONITOR
1472
12
1557
57
Current visitors
count peds with [not (is-staff?)]
0
1
11

MONITOR
1559
12
1640
57
Visitors in total
total-number-of-visitors
0
1
11

SLIDER
10
219
185
252
mean-visiting-time
mean-visiting-time
5
100
5.0
1
1
minutes
HORIZONTAL

BUTTON
1405
675
1579
708
Start/stop observe agent
observe-agent
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
1581
675
1755
708
Start/stop observe display
observe-display
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
10
254
184
287
staff-members-per-level
staff-members-per-level
0
10
0.0
1
1
NIL
HORIZONTAL

SLIDER
188
219
364
252
max-visiting-time
max-visiting-time
5
100
60.0
1
1
minutes
HORIZONTAL

SWITCH
188
254
364
287
staff-switches-levels?
staff-switches-levels?
0
1
-1000

SLIDER
10
289
185
322
mean-treatment-time
mean-treatment-time
0
30
15.0
1
1
minutes
HORIZONTAL

MONITOR
1398
12
1469
57
Employees
count peds with [is-staff?]
0
1
11

SWITCH
13
520
185
553
consider-people-at-adjacent-displays?
consider-people-at-adjacent-displays?
0
1
-1000

TEXTBOX
12
332
162
350
Airport scenario settings
11
0.0
1

SLIDER
11
349
186
382
gate-open-period
gate-open-period
0
60
6.0
1
1
minutes
HORIZONTAL

SLIDER
190
349
360
382
mean-passenger-number
mean-passenger-number
0
1000
90.0
1
1
passengers
HORIZONTAL

TEXTBOX
11
201
161
219
Hospital scenario settings
11
0.0
1

MONITOR
1400
156
1538
201
Contacts between visitors
visitor-contacts / 2
0
1
11

BUTTON
1407
745
1579
778
Transform nodes (CSV)
transform-nodes
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
189
787
360
820
enable-gis-extension?
enable-gis-extension?
1
1
-1000

SWITCH
190
520
364
553
force-all-visitors-to-stick-to-one-ways?
force-all-visitors-to-stick-to-one-ways?
0
1
-1000

MONITOR
1542
156
1655
201
Visitor-staff contacts
visitor-staff-contacts / 2
0
1
11

MONITOR
1659
156
1756
201
Staff contacts
staff-contacts / 2
0
1
11

SWITCH
13
556
185
589
scan-movement-directions?
scan-movement-directions?
0
1
-1000

MONITOR
1401
204
1570
249
Arrival contacts
round arrival-contacts / 2
0
1
11

MONITOR
1573
204
1757
249
Departure contacts
round departure-contacts / 2
0
1
11

@#$#@#$#@
## WHAT IS IT?

This model simulates people in indoor envirionments being guided by public displays.
The displays show dynamic content and aim to guide the people to their destination with a minimum amount of contacts to other people.

## HOW IT WORKS

The people move towards their destination along a path and are also aware of each other. They keep some distance to other agents and follow the instructions of the public displays whenever they encounter them (if they are not familiar with the building). The detection of other agents around public displays is achieved by scanning the surrounding area everytime a person needs further instructions.

## HOW TO USE IT

To initialize the simulation, select a scenario, choose your preferences and click setup. By clicking simulate, the simulation runs automatically.

## THE SCENARIOS

Hospital - UKM in Münster
Airport - Terminal A of Düsseldorf International Airport
Testing Environment 1 - Basic Grid
Testing Environment 2 - Basic Grid with one way system
Testing Environment 3 - Basic Grid with mixture of one ways and regular paths
Testing Environment 4 - More complex single level floor
Testing Environment 5 - More complex single level floor with restricted areas
Testing Environment 6 - Multilevel building with 4 floors and a single stairway
Testing Environment 7 - UKM single level
Testing Environment 8 - UKM single level with restricted staff area and one way areas
Testing Environment 9 - UKM multi level
Testing Environment 10 - UKM multi level with restricted paths

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
NetLogo 6.1.0
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
