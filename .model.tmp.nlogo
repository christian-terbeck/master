; @model Optimizing Social Distance Keeping in Indoor Environments via a Public Display Navigation Support System
; @author Christian Terbeck <christian.terbeck@uni-muenster.de>
;
; @description This model simulates the movement of people in indoor environments while considering social forces.
;              Public displays are used to guide the people with the aim to reduce contacts between them.

;Todo:
; - as time is the time in seconds, this helps to define visiting minutes and waiting tolerance as well as level switching duration (currently its too fast)!
; -> solve temporal scale end then also the spatial scale (contact radius in m and area of awareness etc.; store floorplan scale in config file for every scenario!)
; - fix single and multi-level UKM floorplans
; - function that staff can switch levels
; - distinguish between contacts between visitors and contacts where staff members are involved!!!
; - adjust public display logic so that also the sensors of nearby displays are taken into account!
; - average contact duration must be calculated as seconds!
; - individual waiting time for each agent (random value near mean value)
; - staff should not leave building! always next destination!!! -> on their level only!
; - staff should be there at the very beginning of the simulation on setup - staff does not start at building entrance!
; - individual waiting tolerance per agent!
; - distinguish between staff members and visitors by is-staff? in addition to familiarity as this is misleading!!! familiarity could be an additional attribute but restriction to paths applies to familiar visitors as well.
; - how to use familiarity rate now? are visitors not forced to follow signs? probably only forced to stop.
; - Fix and finish environments (Finalize UKM tower and INCLUDE elevators and add directed links - one way in towers)
; - Fix bugs (e.g. contact stamps -> also show in Thesis where the contacts occur; for discussion etc.
; - maybe only force non-staff people to stick to one-ways?
; - when doing airport: use patch color of transport bands to increase agent speed, draw paths along them to make movement possible there

extensions [csv gis]

globals [
  interface-width
  dim-x
  dim-y
  resource-path
  output-path
  output-ticks
  output-contacts
  output-critical-contacts
  output-unique-contacts
  total-number-of-visitors
  total-number-of-familiar-people
  time
  levels
  level-switching-duration
  overall-contacts
  overall-contact-time
  unique-contacts
  critical-contacts
  contact-distance-values
  contact-distance
  scenario-has-one-way-paths?
]

breed [peds ped]
peds-own [
  is-initialized?
  has-moved?
  speedx
  speedy
  is-staff?
  is-familiar?
  is-visiting?
  has-visited?
  visiting-time
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

  set-environment
  set-nodes
  set-agents

  if show-logs? [
    print "- Setup complete, you may start the simulation now -"
  ]
end

;Todo add scenario default settings here

; @method restore-default-settings
; @description Restores the default scenario settings

to restore-default-settings
  set use-stop-feature? true
  set use-static-signage? false

  ifelse scenario = "airport" [
    set area-of-awareness 50
  ] [
    set area-of-awareness 20
  ]

  if show-logs? [
    print word "Restored default settings for " word scenario " scenario"
  ]

  setup
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

  set interface-width 80

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

    create-link-from myself [
      tie
      hide-link
    ]
  ]
end

; @method set-nodes
; @description Loads the nodes and their links from external sources and adds them to the world

to set-nodes
  set scenario-has-one-way-paths? false

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

    if not member? level levels [
      set levels lput level levels
    ]
  ]

  ask nodes [
    ifelse patch-size < 10 [
      set size 10 / patch-size
    ] [
      set size 1
    ]

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
  if staff-members-per-level > 0 [
    repeat staff-members-per-level [
      foreach levels [x ->
        create-ped true true x
      ]
    ]
  ]

  repeat initial-number-of-people [
    create-ped false false -1
  ]

  if count peds with [(not is-staff?)] > 0 [
    ask n-of round (familiarity-rate * total-number-of-visitors) peds with [(not is-staff?)] [
      make-familiar self
    ]
  ]

  ask peds [
    init-ped self
  ]
end

; @method create-ped
; @param bool is-staff?
; @param int level
; @description Creates a new ped and sets its attributes

to create-ped [is-familiar-with-building? is-staff-member? level-number]
  let x 0
  let y 0
  let tmp-first-node nobody

  ifelse level-number > -1 [
    ask one-of nodes with [level = level-number and is-destination?] [
      set x pxcor
      set y pycor
      set tmp-first-node self
    ]
  ] [
    ask one-of nodes with [is-origin?] [
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

      set color white
      set is-familiar? true
    ] [
      set shape "person"
      set color cyan
      set is-familiar? is-familiar-with-building?
    ]

    ifelse patch-size < 10 [
      set size 10 / patch-size
    ] [
      set size 1
    ]

    set xcor x + random-normal 0 0.2
    set ycor y + random-normal 0 0.2
    set is-initialized? false
    set has-moved? false
    set is-visiting? true
    set visiting-time mean-visiting-time + random-normal 0 5

    if visiting-time > max-visiting-time [
      set visiting-time max-visiting-time
    ]

    if visiting-time < 5 [
      set visiting-time 5
    ]

    set has-visited? false
    set is-waiting? false
    set waiting-tolerance mean-waiting-tolerance + random-normal 0 120

    if waiting-tolerance < 10 [
      set waiting-tolerance 10
    ]

    set origin tmp-first-node
    set current-level [level] of tmp-first-node

    ifelse is-staff? and not staff-switches-levels? [
      set destination one-of nodes with [is-destination? and not (self = tmp-first-node) and (level = [level] of tmp-first-node)]
    ] [
      set destination one-of nodes with [is-destination? and not (self = tmp-first-node)]
    ]

    set had-contact-with []
    set active-contacts []
    set active-contacts-periods []
    set label-color black
  ]

  set total-number-of-visitors total-number-of-visitors + 1
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
  set color blue

  set total-number-of-familiar-people total-number-of-familiar-people + 1
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

  let path-file word resource-path word "paths/" word [who] of node1 word "-" word [who] of node2 "-a.csv"
  let path-file-2 word resource-path word "paths/" word [who] of node2 word "-" word [who] of node1 "-a.csv"

  if not is-staff? [
    set path-file word resource-path word "paths/" word [who] of node1 word "-" word [who] of node2 "-r.csv"
    set path-file-2 word resource-path word "paths/" word [who] of node2 word "-" word [who] of node1 "-r.csv"
  ]

  ifelse file-exists? path-file [
    file-open path-file
    let tmp-nodes []
    let tmp-path []

    while [not file-at-end?] [
      set tmp-nodes (csv:from-row file-read-line ",")

      set tmp-path []

      foreach tmp-nodes [i ->
        set tmp-path lput node i tmp-path
      ]

      set paths lput tmp-path paths
    ]

    file-close

    if show-logs? [
      print word "Loaded paths from cached file " path-file
    ]
  ] [
    ifelse file-exists? path-file-2 and not scenario-has-one-way-paths? [
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

  ;ifelse not use-static-signage? and not is-familiar? and current-node-has-display? [
  ifelse not use-static-signage? and not is-staff? and current-node-has-display? [
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
          ask patches in-cone area-of-awareness angle-of-awareness with [pcolor > 8.5] [
            set pcolor yellow
          ]
        ]

        set tmp-detected-people count peds in-cone area-of-awareness angle-of-awareness with [not (self = k) and not (hidden?)]

        if detected-people = -1 or (detected-people > 0 and tmp-detected-people < detected-people) [
          set detected-people tmp-detected-people
          set least-crowded-adjacent-node cur-node
        ]
      ]
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
    let out-links [my-out-links] of last i

    if not is-staff? [
      set out-links [my-out-links with [not is-restricted?]] of last i
    ]

    let reachable-nodes []

    ask out-links [
      ask both-ends [
        if [who] of self != [who] of last i [
          set reachable-nodes lput self reachable-nodes
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

    ask peds in-radius contact-radius with [not (self = myself) and not (hidden?)] [
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

; @method move
; @description Moves the ped
; @param ped k

to move [k]
  let hd towards next-node
  let h hd
  let repx 0
  let repy 0

  if not (speedx * speedy = 0) [
    set h atan speedx speedy
  ]

  ;Todo: adjust and maybe move to external report function?

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

  ask patches in-radius (D) with [pcolor < 1.5] [
    set repx repx + (A * exp((1 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h))) / 5
    set repy repy + (A * exp((1 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h))) / 5
  ]

  set speedx speedx + dt * (repx + (V0 * sin hd - speedx) / Tr)
  set speedy speedy + dt * (repy + (V0 * cos hd - speedy) / Tr)

  if distance next-node < D / 2 or not has-moved? [
    if distance next-node < D / 2 [
      set last-node next-node
    ]

    ifelse distance destination < D / 2 [
      if show-logs? [
        print word self " has reached its destination"
      ]

      ifelse is-visiting? and not has-visited? [
        ifelse visiting-time > 0 [
          if not hidden? [
            hide-me self
          ]
          error "Todo: calculate visiting time as seconds"
          set visiting-time visiting-time - 1
        ] [
          init-paths self destination origin
          update-path self origin

          set has-visited? true
          show-me self
        ]
      ] [
        ask in-link-neighbors [
          die
        ]

        ask out-link-neighbors [
          hide-turtle
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
        if has-moved? [
          ifelse not is-familiar? [
            set paths map [i -> but-first i] (filter [i -> item 1 i = next-node] paths)
            update-path self next-node
          ] [
            set next-node item pos current-path
          ]
        ]
      ]
    ]
  ]

  set xcor xcor + speedx * dt
  set ycor ycor + speedy * dt

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
    ifelse is-waiting? [
      update-path self last-node
    ] [
      move self
    ]
  ]

  if spawn-rate > 0 and ticks > 0 and ticks mod spawn-rate = 0 and count peds < max-capacity [
    create-ped false false -1

    ask peds with [not (is-initialized?)] [
      if familiarity-rate > 0 and ((total-number-of-familiar-people > 0 and total-number-of-familiar-people / total-number-of-visitors < familiarity-rate) or total-number-of-familiar-people < 1) [
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
1189
820
-1
-1
1.0
1
10
1
1
1
0
0
0
1
-400
400
-400
400
0
0
1
Ticks
30.0

SLIDER
8
120
183
153
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
1469
453
1644
486
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
1590
10
1645
55
Time
time
17
1
11

MONITOR
1535
10
1586
55
Density
count peds / world-width / world-height
3
1
11

SLIDER
1291
453
1466
486
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
1469
489
1644
522
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
1292
489
1466
522
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
1292
525
1467
558
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
658
185
691
show-logs?
show-logs?
1
1
-1000

SLIDER
11
456
183
489
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
186
456
359
489
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
11
492
183
525
contact-tolerance
contact-tolerance
0
10
5.0
1
1
ticks
HORIZONTAL

MONITOR
1290
58
1465
103
Number of contacts
overall-contacts / 2
0
1
11

MONITOR
1470
58
1646
103
Avg. number of contacts per person
overall-contacts / 2 / (total-number-of-visitors + count peds with [is-staff?])
3
1
11

MONITOR
1290
106
1466
151
Unique contacts
unique-contacts / 2
0
1
11

MONITOR
1470
106
1646
151
Critical contacts
critical-contacts / 2
0
1
11

MONITOR
1290
154
1467
199
Avg. contact duration
overall-contact-time / overall-contacts
3
1
11

MONITOR
1471
154
1646
199
Avg. contact distance
contact-distance / contact-distance-values
3
1
11

PLOT
1291
205
1647
418
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
186
493
358
526
show-circles?
show-circles?
1
1
-1000

SWITCH
11
694
186
727
show-labels?
show-labels?
1
1
-1000

SLIDER
11
325
184
358
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
10
621
184
654
show-paths?
show-paths?
1
1
-1000

SWITCH
187
621
363
654
show-walking-paths?
show-walking-paths?
1
1
-1000

SWITCH
187
659
363
692
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
"hospital" "airport" "testing-environment-1" "testing-environment-2" "testing-environment-3" "testing-environment-4" "testing-environment-5" "testing-environment-6" "testing-environment-7" "testing-environment-8" "testing-environment-9"
0

SWITCH
10
556
184
589
write-output?
write-output?
0
1
-1000

INPUTBOX
189
795
362
855
stop-at-ticks
30000.0
1
0
Number

SLIDER
188
325
362
358
angle-of-awareness
angle-of-awareness
0
90
19.0
1
1
degrees
HORIZONTAL

SWITCH
11
396
183
429
show-areas-of-awareness?
show-areas-of-awareness?
0
1
-1000

SLIDER
187
556
359
589
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
12
540
162
558
Output generation
11
0.0
1

TEXTBOX
12
307
162
325
Public Display settings
11
0.0
1

TEXTBOX
12
440
162
458
Contact settings
11
0.0
1

TEXTBOX
11
603
161
621
Additional options
11
0.0
1

TEXTBOX
1294
436
1589
464
Speed and Social Force (maybe just remove from interface)
11
0.0
1

SWITCH
11
360
184
393
use-stop-feature?
use-stop-feature?
0
1
-1000

SWITCH
188
396
361
429
use-static-signage?
use-static-signage?
1
1
-1000

SLIDER
188
360
361
393
mean-waiting-tolerance
mean-waiting-tolerance
0
1800
30.0
10
1
seconds
HORIZONTAL

BUTTON
12
759
187
792
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
15
742
165
760
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
180.0
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
100
12.0
1
1
visitors
HORIZONTAL

MONITOR
1363
10
1448
55
Current visitors
count peds with [not (is-staff?)]
0
1
11

MONITOR
1450
10
1531
55
Visitors in total
total-number-of-visitors
0
1
11

SLIDER
9
192
184
225
mean-visiting-time
mean-visiting-time
5
100
23.0
1
1
minutes
HORIZONTAL

BUTTON
189
759
362
792
Restore scenario defaults
restore-default-settings
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
13
795
187
828
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
13
831
187
864
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
9
227
183
260
staff-members-per-level
staff-members-per-level
0
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
187
192
363
225
max-visiting-time
max-visiting-time
5
100
30.0
1
1
minutes
HORIZONTAL

SWITCH
187
227
363
260
staff-switches-levels?
staff-switches-levels?
1
1
-1000

SLIDER
9
262
184
295
mean-treatment-time
mean-treatment-time
0
30
5.0
1
1
minutes
HORIZONTAL

MONITOR
1290
10
1361
55
Employees
count peds with [is-staff?]
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
Airport - Amsterdam Schiphol
Testing Environment 1 - Basic Grid
Testing Environment 2 - Basic Grid with one way system
Testing Environment 3 - Basic Grid with mixture of one ways and regular paths
Testing Environment 4 - More complex single level floor
Testing Environment 5 - More complex single level floor with restricted areas
Testing Environment 6 - Multilevel building with 4 floors and a single stairway
Testing Environment 7 - UKM single level
Testing Environment 8 - UKM single level with restricted staff area and one way areas
Testing Environment 9 - UKM multi level

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
