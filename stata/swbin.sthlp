{smcl}
{* *! version 1.2.0 02jul2026}{...}
{viewerjumpto "Syntax" "swbin##syntax"}{...}
{viewerjumpto "Description" "swbin##description"}{...}
{viewerjumpto "Options" "swbin##options"}{...}
{viewerjumpto "Examples" "swbin##examples"}{...}
{viewerjumpto "Stored results" "swbin##results"}{...}
{viewerjumpto "References" "swbin##references"}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col :{cmd:swbin}}Create stabilized weights for a binary treatment/exposure{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:swbin} {it:exposure} {it:covariates} {ifin},
{opt sw(newvar)}
[
{opt psden(newvar)}
{opt psnum(newvar)}
{opt method(method)}
{opt replace}
]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt sw(newvar)}}name of the variable to store stabilized weights; required{p_end}
{synopt :{opt psden(newvar)}}name of the denominator propensity score variable; default is {cmd:ps_den}{p_end}
{synopt :{opt psnum(newvar)}}name of the numerator probability variable; default is {cmd:ps_num}{p_end}
{synopt :{opt method(method)}}denominator model; {cmd:logit}, {cmd:probit}, or {cmd:firthlogit}; default is {cmd:logit}{p_end}
{synopt :{opt replace}}replace existing output variables{p_end}
{synoptline}

{marker description}{...}
{title:Description}

{pstd}
{cmd:swbin} creates stabilized weights for a binary treatment or exposure.
The first variable in {it:varlist} is treated as the exposure variable and must
be numeric and coded 0/1. The remaining variables are used as covariates in the
denominator propensity score model.

{pstd}
Let {it:A} denote the binary exposure and {it:L} denote baseline covariates.
{cmd:swbin} creates stabilized weights as follows:

{p 8 12 2}
For {it:A} = 1: {cmd:SW = P(A=1) / P(A=1|L)}{p_end}
{p 8 12 2}
For {it:A} = 0: {cmd:SW = P(A=0) / P(A=0|L)}{p_end}

{pstd}
The denominator propensity score {cmd:P(A=1|L)} is estimated using the method
specified by {cmd:method()}. The numerator probability {cmd:P(A=1)} is always
estimated using an intercept-only standard logistic regression.

{pstd}
Factor-variable notation is allowed in the covariate list.

{marker options}{...}
{title:Options}

{phang}
{opt sw(newvar)} specifies the name of the variable in which to store the
stabilized weights. This option is required.

{phang}
{opt psden(newvar)} specifies the name of the denominator propensity score
variable, {cmd:P(A=1|L)}. The default is {cmd:ps_den}.

{phang}
{opt psnum(newvar)} specifies the name of the numerator probability variable,
{cmd:P(A=1)}. The default is {cmd:ps_num}.

{phang}
{opt method(method)} specifies the model used for the denominator propensity
score. Allowed values are {cmd:logit}, {cmd:probit}, and {cmd:firthlogit}.
The default is {cmd:logit}.

{pmore}
When {cmd:method(firthlogit)} is specified, {cmd:swbin} fits a Firth logistic
model for the denominator propensity score and then applies intercept correction
(FLIC). The FLIC correction is applied to the denominator model only. The
numerator model remains an intercept-only standard logistic regression.

{pmore}
{cmd:method(firthlogit)} requires the user-written command {cmd:firthlogit}.

{phang}
{opt replace} allows {cmd:swbin} to drop and recreate existing output
variables specified by {cmd:psden()}, {cmd:psnum()}, and {cmd:sw()}.

{marker examples}{...}
{title:Examples}

{pstd}Basic example using standard logistic regression for the denominator model:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. swbin foreign price mpg weight length, sw(sw)}{p_end}
{phang2}{cmd:. summarize ps_den ps_num sw, detail}{p_end}

{pstd}Specify output variable names:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. swbin foreign price mpg weight length, psden(ps_d) psnum(ps_n) sw(sw_foreign)}{p_end}

{pstd}Use factor-variable notation:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. swbin foreign price mpg weight i.rep78, sw(sw) replace}{p_end}

{pstd}Use a probit denominator model:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. swbin foreign price mpg weight length, sw(sw_probit) method(probit) replace}{p_end}

{pstd}Use Firth logistic regression with FLIC for the denominator model:{p_end}

{phang2}{cmd:. ssc install firthlogit}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. swbin foreign price mpg weight length, sw(sw_flic) psden(ps_den_flic) psnum(ps_num) method(firthlogit) replace}{p_end}

{marker diagnostics}{...}
{title:Suggested diagnostics}

{pstd}
{cmd:swbin} creates weights but does not perform balance diagnostics or weight
truncation. Users should examine the distribution of the propensity score and
weights and assess covariate balance before using the weights in outcome models.

{phang2}{cmd:. summarize sw, detail}{p_end}
{phang2}{cmd:. histogram sw, bin(50)}{p_end}
{phang2}{cmd:. summarize ps_den, detail}{p_end}
{phang2}{cmd:. histogram ps_den, bin(50)}{p_end}
{phang2}{cmd:. tabstat ps_den sw, by(foreign) statistics(n mean sd min p25 p50 p75 max)}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:swbin} stores the following in {cmd:r()}:

{synoptset 30 tabbed}{...}
{p2col 5 30 34 2:Scalars}{p_end}
{synopt :{cmd:r(N_initial)}}initial analysis sample size{p_end}
{synopt :{cmd:r(N_denominator)}}denominator model sample size{p_end}
{synopt :{cmd:r(N_final)}}final weighted sample size{p_end}
{synopt :{cmd:r(N_missing_all)}}number of missing stabilized weights in the full data{p_end}
{synopt :{cmd:r(N_missing_analysis_sample)}}number of missing stabilized weights in the analysis sample{p_end}
{synopt :{cmd:r(sw_mean)}}mean stabilized weight{p_end}
{synopt :{cmd:r(sw_min)}}minimum stabilized weight{p_end}
{synopt :{cmd:r(sw_max)}}maximum stabilized weight{p_end}
{synopt :{cmd:r(trt_mean_den)}}observed exposure proportion in the denominator sample; only with {cmd:method(firthlogit)}{p_end}
{synopt :{cmd:r(psden_mean_flic)}}mean FLIC denominator propensity score; only with {cmd:method(firthlogit)}{p_end}

{p2col 5 30 34 2:Macros}{p_end}
{synopt :{cmd:r(exposure)}}exposure variable name{p_end}
{synopt :{cmd:r(covariates)}}covariate list{p_end}
{synopt :{cmd:r(method)}}method specified in {cmd:method()}{p_end}
{synopt :{cmd:r(den_method)}}denominator model method{p_end}
{synopt :{cmd:r(num_method)}}numerator model method{p_end}
{synopt :{cmd:r(psden)}}denominator propensity score variable name{p_end}
{synopt :{cmd:r(psnum)}}numerator probability variable name{p_end}
{synopt :{cmd:r(sw)}}stabilized weight variable name{p_end}

{marker limitations}{...}
{title:Limitations}

{pstd}
{cmd:swbin} is designed for binary treatment/exposure variables only. It does
not support multivalued, continuous, or time-varying treatments. It does not
perform weight trimming, weight truncation, or covariate balance diagnostics.

{marker references}{...}
{title:References}

{phang}
Robins JM, Hernan MA, Brumback B. 2000. Marginal structural models and causal
inference in epidemiology. {it:Epidemiology} 11(5):550-560.

{phang}
Cole SR, Hernan MA. 2008. Constructing inverse probability weights for marginal
structural models. {it:American Journal of Epidemiology} 168(6):656-664.

{phang}
Hernan MA, Robins JM. {it:Causal Inference: What If}. Chapman & Hall/CRC.

{phang}
Firth D. 1993. Bias reduction of maximum likelihood estimates.
{it:Biometrika} 80(1):27-38.

{phang}
Puhr R, Heinze G, Nold M, Lusa L, Geroldinger A. 2017. Firth's logistic
regression with rare events: accurate effect estimates and predictions?
{it:Statistics in Medicine} 36(14):2302-2317.

{title:Author}

{pstd}
Toshiharu Mitsuhashi{break}
GitHub: {browse "https://github.com/sankyoh":@sankyoh}

{title:Also see}

{psee}
Online: {helpb logit}, {helpb probit}, {helpb glm}, {helpb stcox}
