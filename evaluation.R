library(nlrx)

netlogopath <- file.path("C:/Program Files/NetLogo 6.1.0")
modelpath <- file.path("C:/Users/chris/github/master/model6-1.nlogo")
outpath <- file.path("C:/Users/chris/github/master/output/r")

nl <- nl(nlversion = "6.1.0",
         nlpath = netlogopath,
         modelpath = modelpath,
         jvmmem = 1024)

print(nl)

nl@experiment <- experiment(expname="hospital",
                            outpath=outpath,
                            repetition=1,
                            tickmetrics="false",
                            idsetup="setup",
                            idgo="simulate",
                            runtime=30000,
                            evalticks=seq(40,50),
                            metrics=c("time", "overall-contacts / 2"),
                            variables = list('familiarity-rate' = list(min=0, max=1, qfun="qunif")),
                            constants = list("scenario" = "\"hospital\"",
                                             "dt" = 0.5,
                                             "initial-number-of-visitors" = 0,
                                             "staff-members-per-level" = 4,
                                             "spawn-rate" = 120,
                                             "mean-visiting-time" = 30,
                                             "max-visiting-time" = 60,
                                             "max-capacity" = 120,
                                             "area-of-awareness" = 10,
                                             "angle-of-awareness" = 15,
                                             "show-areas-of-awareness?" = "false"))


eval_variables_constants(nl)

nl@simdesign <- simdesign_lhs(nl=nl,
                              samples=1,
                              nseeds=3,
                              precision=3)

print(nl)

results <- run_nl_all(nl = nl)

setsim(nl, "simoutput") <- results
write_simoutput(nl)
analyze_nl(nl)
