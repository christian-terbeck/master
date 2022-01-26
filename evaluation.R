library(nlrx)

netlogopath <- file.path("C:/Program Files/NetLogo 6.2.0")
modelpath <- file.path("C:/Users/chris/github/master/model6-2.nlogo")
outpath <- file.path("C:/Users/chris/github/master/output/r")

nl <- nl(nlversion = "6.1.0",
         nlpath = netlogopath,
         modelpath = modelpath,
         jvmmem = 1024)

printnl@experiment <- experiment(expname="hospital",
                            outpath=outpath,
                            repetition=1,
                            tickmetrics="true",
                            idsetup="setup",
                            idgo="simulate",
                            runtime=50,
                            evalticks=seq(40,50),
                            metrics=c("time", "contacts / 2"),
                            variables = list('familiarity-rate' = list(min=0, max=1, qfun="qunif")),
                            constants = list("scenario" = "\"hospital\"",
                                             "initial-number-of-visitors" = 0,
                                             "staff-members-per-level" = 4,
                                             "spawn-rate" = 180,
                                             "mean-visiting-time" = 30,
                                             "max-visiting-time" = 60,
                                             "max-capacity" = 120,
                                             "area-of-awareness" = 10,
                                             "angle-of-awareness" = 15,
                                             "show-areas-of-awareness?" = "false"))

nl@simdesign <- simdesign_lhs(nl=nl,
                              samples=100,
                              nseeds=3,
                              precision=3)

print(nl)

results <- run_nl_all(nl = nl)
