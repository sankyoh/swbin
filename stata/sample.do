****************************************************
* sample.do
* Example do-file for swbin v1.2.0
*
* Repository:
*   https://github.com/sankyoh/swbin
*
* Installation:
*   net install swbin, from("https://raw.githubusercontent.com/sankyoh/swbin/main/stata") replace
****************************************************

version 16.0
clear all
set more off

****************************************************
* 0. Check installation
****************************************************

which swbin

****************************************************
* 1. Basic example: denominator model by logit
****************************************************

sysuse auto, clear

swbin foreign price mpg weight length, ///
    sw(sw_logit) ///
    psden(ps_den_logit) ///
    psnum(ps_num_logit) ///
    replace

summarize ps_den_logit ps_num_logit sw_logit, detail
tabstat ps_den_logit sw_logit, by(foreign) ///
    statistics(n mean sd min p25 p50 p75 max)

****************************************************
* 2. Example with factor-variable notation
****************************************************

sysuse auto, clear

swbin foreign price mpg weight i.rep78, ///
    sw(sw_fv) ///
    psden(ps_den_fv) ///
    psnum(ps_num_fv) ///
    replace

summarize ps_den_fv ps_num_fv sw_fv, detail

****************************************************
* 3. Example with if restriction
****************************************************

sysuse auto, clear

swbin foreign mpg weight length if price < 10000, ///
    sw(sw_if) ///
    psden(ps_den_if) ///
    psnum(ps_num_if) ///
    replace

summarize ps_den_if ps_num_if sw_if, detail

****************************************************
* 4. Example using probit for the denominator model
****************************************************

sysuse auto, clear

swbin foreign price mpg weight length, ///
    sw(sw_probit) ///
    psden(ps_den_probit) ///
    psnum(ps_num_probit) ///
    method(probit) ///
    replace

summarize ps_den_probit ps_num_probit sw_probit, detail

****************************************************
* 5. Example using Firth logistic regression + FLIC
****************************************************

capture which firthlogit
if _rc == 0 {

    sysuse auto, clear

    swbin foreign price mpg weight length, ///
        sw(sw_flic) ///
        psden(ps_den_flic) ///
        psnum(ps_num_flic) ///
        method(firthlogit) ///
        replace

    summarize ps_den_flic ps_num_flic sw_flic, detail

}
else {

    display as text "firthlogit is not installed."
    display as text "To run the FLIC example, install it first:"
    display as result "    ssc install firthlogit"

}

****************************************************
* 6. Example outcome model after weighting
*
* This is only an illustrative example using auto.dta.
* Users should define an appropriate outcome model for their own study.
****************************************************

sysuse auto, clear

swbin foreign price mpg weight length, ///
    sw(sw) ///
    replace

* Example: weighted linear regression
regress price foreign [pweight = sw], vce(robust)

****************************************************
* End of file
****************************************************
