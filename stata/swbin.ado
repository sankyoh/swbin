*! swbin.ado
*! version 1.2.0
*! Create stabilized weights for binary treatment/exposure
*! method(firthlogit) uses FLIC for the denominator propensity score only
*! Author: Toshiharu Mitsuhashi (@sankyoh)
*! Date: 2026/06/24

program define swbin, rclass
    version 16.0

    syntax varlist(min=2 fv) [if] [in], ///
        SW(name) ///
        [ PSDEN(name) PSNUM(name) METHOD(string) REPLACE ]

    *------------------------------------------------------------
    * Parse arguments
    *------------------------------------------------------------
    gettoken trt covars : varlist

    if "`psden'" == "" local psden ps_den
    if "`psnum'" == "" local psnum ps_num
    if "`method'" == "" local method logit

    local method = lower(strtrim("`method'"))

    if !inlist("`method'", "logit", "probit", "firthlogit") {
        di as error "method() must be one of: logit, probit, firthlogit"
        exit 198
    }

    *------------------------------------------------------------
    * Check output variable names
    *------------------------------------------------------------
    local outvars `psden' `psnum' `sw'
    local outuniq : list uniq outvars
    local nout    : word count `outvars'
    local nuniq   : word count `outuniq'

    if `nout' != `nuniq' {
        di as error "Output variable names must be distinct."
        di as error "Current output names: psden(`psden') psnum(`psnum') sw(`sw')"
        exit 198
    }

    foreach v of local outvars {
        if "`v'" == "`trt'" {
            di as error "Output variable `v' cannot be the same as exposure variable `trt'."
            exit 198
        }

        capture confirm variable `v'
        if !_rc & "`replace'" == "" {
            di as error "Variable `v' already exists."
            di as error "Use option replace to overwrite existing variables."
            exit 110
        }
    }

    *------------------------------------------------------------
    * Check firthlogit availability
    *------------------------------------------------------------
    if "`method'" == "firthlogit" {
        capture which firthlogit
        if _rc {
            di as error "firthlogit is not installed."
            di as error "Install it first, for example: ssc install firthlogit"
            exit 199
        }
    }

    *------------------------------------------------------------
    * Define analysis sample
    *
    * marksample uses:
    *   - if / in
    *   - missingness in exposure and covariates
    *------------------------------------------------------------
    marksample touse

    quietly count if `touse'
    local N0 = r(N)

    if `N0' == 0 {
        di as error "No observations in the analysis sample."
        exit 2000
    }

    *------------------------------------------------------------
    * Check treatment/exposure variable
    *------------------------------------------------------------

    capture confirm numeric variable `trt'
    if _rc {
        di as error "Exposure variable `trt' must be numeric."
        di as error "It must be coded as 0/1."
        exit 459
    }

    capture assert inlist(`trt', 0, 1) if `touse'
    if _rc {
        di as error "Exposure variable `trt' must contain only 0 and 1 in the analysis sample."
        di as error "Observed values are:"
        tabulate `trt' if `touse', missing
        exit 459
    }

    quietly levelsof `trt' if `touse', local(levels)
    local nlevels : word count `levels'

    if `nlevels' != 2 {
        di as error "Exposure variable `trt' must contain both 0 and 1 in the analysis sample."
        di as error "Observed level(s): `levels'"
        tabulate `trt' if `touse', missing
        exit 459
    }

    *------------------------------------------------------------
    * Denominator model
    * P(A=1 | L)
    *
    * logit       : standard logistic regression
    * probit      : standard probit regression
    * firthlogit  : Firth logistic regression + intercept correction
    *              = FLIC
    *------------------------------------------------------------

    tempvar sample_den psden_tmp

    if inlist("`method'", "logit", "probit") {

        capture quietly `method' `trt' `covars' if `touse'
        if _rc {
            di as error "Denominator model failed."
            di as error "Model: `method' `trt' `covars'"
            exit _rc
        }

        tempname conv
        capture scalar `conv' = e(converged)
        if !_rc {
            if scalar(`conv') != 1 {
                di as error "Denominator model did not converge."
                di as error "Model: `method' `trt' `covars'"
                exit 430
            }
        }

        gen byte `sample_den' = e(sample)

        quietly count if `sample_den'
        local Nden = r(N)

        if `Nden' == 0 {
            di as error "Denominator model used zero observations."
            exit 2000
        }

        if `Nden' < `N0' {
            di as text "Note: denominator model used fewer observations than the initial analysis sample."
            di as text "Initial analysis sample N = `N0'; denominator model sample N = `Nden'"
        }

        capture predict double `psden_tmp' if `sample_den', pr
        if _rc {
            di as error "Prediction after denominator model failed."
            exit _rc
        }
    }

    if "`method'" == "firthlogit" {

        tempvar xb_firth eta_firth
        tempname conv gamma0 firth_cons

        *--------------------------------------------------------
        * 1) Firth logistic regression
        *--------------------------------------------------------
        capture quietly firthlogit `trt' `covars' if `touse'
        if _rc {
            di as error "Denominator Firth logistic model failed."
            di as error "Model: firthlogit `trt' `covars'"
            exit _rc
        }

        capture scalar `conv' = e(converged)
        if !_rc {
            if scalar(`conv') != 1 {
                di as error "Denominator Firth logistic model did not converge."
                di as error "Model: firthlogit `trt' `covars'"
                exit 430
            }
        }

        gen byte `sample_den' = e(sample)

        quietly count if `sample_den'
        local Nden = r(N)

        if `Nden' == 0 {
            di as error "Denominator Firth logistic model used zero observations."
            exit 2000
        }

        if `Nden' < `N0' {
            di as text "Note: denominator model used fewer observations than the initial analysis sample."
            di as text "Initial analysis sample N = `N0'; denominator model sample N = `Nden'"
        }

        *--------------------------------------------------------
        * 2) Get linear predictor from Firth logistic model
        *--------------------------------------------------------
        capture predict double `xb_firth' if `sample_den', xb
        if _rc {
            di as error "Prediction of xb after firthlogit failed."
            exit _rc
        }

        capture scalar `firth_cons' = _b[_cons]
        if _rc {
            di as error "The constant term _b[_cons] was not found after firthlogit."
            di as error "FLIC requires a model with an intercept."
            exit 498
        }

        *--------------------------------------------------------
        * 3) Remove Firth intercept from xb
        *    eta_i = xb_i - beta0_firth
        *--------------------------------------------------------
        gen double `eta_firth' = `xb_firth' - scalar(`firth_cons') if `sample_den'

        *--------------------------------------------------------
        * 4) Re-estimate only the intercept using ML
        *    logit trt, offset(eta_i)
        *
        *    This gives gamma0, the FLIC intercept.
        *--------------------------------------------------------
        capture quietly logit `trt' if `sample_den', offset(`eta_firth') nolog
        if _rc {
            di as error "FLIC intercept-correction model failed."
            di as error "Model: logit `trt', offset(eta_firth)"
            exit _rc
        }

        capture scalar `conv' = e(converged)
        if !_rc {
            if scalar(`conv') != 1 {
                di as error "FLIC intercept-correction model did not converge."
                exit 430
            }
        }

        scalar `gamma0' = _b[_cons]

        *--------------------------------------------------------
        * 5) Calculate FLIC predicted probability
        *    p_i = invlogit(eta_i + gamma0)
        *--------------------------------------------------------
        gen double `psden_tmp' = invlogit(`eta_firth' + scalar(`gamma0')) if `sample_den'

        *--------------------------------------------------------
        * 6) Check: mean predicted probability should match
        *    observed exposure prevalence in denominator sample.
        *--------------------------------------------------------
        quietly summarize `trt' if `sample_den', meanonly
        local trt_mean_den = r(mean)

        quietly summarize `psden_tmp' if `sample_den', meanonly
        local psden_mean_flic = r(mean)
    }

    *------------------------------------------------------------
    * Numerator model
    * P(A=1)
    *
    * Always estimated by intercept-only logit.
    * With an intercept-only model, predicted P(A=1) equals
    * the observed treatment/exposure prevalence in the estimation sample.
    * This avoids using Firth for the numerator probability.
    *------------------------------------------------------------

    tempvar sample_num sample_final psnum_tmp
    tempname conv_num

    capture quietly logit `trt' if `sample_den', nolog
    if _rc {
        di as error "Numerator model failed."
        di as error "Model: logit `trt'"
        exit _rc
    }

    capture scalar `conv_num' = e(converged)
    if !_rc {
        if scalar(`conv_num') != 1 {
            di as error "Numerator model did not converge."
            di as error "Model: logit `trt'"
            exit 430
        }
    }

    gen byte `sample_num' = e(sample)
    gen byte `sample_final' = `sample_den' & `sample_num'

    quietly count if `sample_final'
    local Nfinal = r(N)

    if `Nfinal' == 0 {
        di as error "Final sample has zero observations."
        exit 2000
    }

    capture predict double `psnum_tmp' if `sample_final', pr
    if _rc {
        di as error "Prediction after numerator model failed."
        exit _rc
    }

    *------------------------------------------------------------
    * Check predicted probabilities
    *------------------------------------------------------------

    quietly count if `sample_final' & ///
        (missing(`psden_tmp') | missing(`psnum_tmp') | ///
         `psden_tmp' <= 0 | `psden_tmp' >= 1 | ///
         `psnum_tmp' <= 0 | `psnum_tmp' >= 1)

    if r(N) > 0 {
        di as error "Some predicted probabilities are missing or outside the open interval (0, 1)."
        di as error "Stabilized weights cannot be safely calculated."
        exit 459
    }

    *------------------------------------------------------------
    * Calculate stabilized weight
    *------------------------------------------------------------

    tempvar sw_tmp
    gen double `sw_tmp' = .

    replace `sw_tmp' = `psnum_tmp' / `psden_tmp' ///
        if `trt' == 1 & `sample_final'

    replace `sw_tmp' = (1 - `psnum_tmp') / (1 - `psden_tmp') ///
        if `trt' == 0 & `sample_final'

    *------------------------------------------------------------
    * Create or replace output variables
    *------------------------------------------------------------

    foreach v of local outvars {
        capture confirm variable `v'

        if !_rc {
            drop `v'
            gen double `v' = .
        }
        else {
            gen double `v' = .
        }
    }

    quietly replace `psden' = `psden_tmp' if `sample_den'
    quietly replace `psnum' = `psnum_tmp' if `sample_final'
    quietly replace `sw'    = `sw_tmp'    if `sample_final'

    if "`method'" == "firthlogit" {
        label variable `psden' "Denominator propensity score: FLIC Pr(`trt'=1 | L)"
    }
    else {
        label variable `psden' "Denominator propensity score: Pr(`trt'=1 | L)"
    }

    label variable `psnum' "Numerator propensity score: Pr(`trt'=1)"
    label variable `sw'    "Stabilized weight for `trt'"

    *------------------------------------------------------------
    * Display results
    *------------------------------------------------------------

    quietly count if missing(`sw')
    local Nmiss_all = r(N)

    quietly count if `touse' & missing(`sw')
    local Nmiss_touse = r(N)

    quietly summarize `sw' if `sample_final', meanonly
    local sw_mean = r(mean)
    local sw_min  = r(min)
    local sw_max  = r(max)

    di as text _newline "Stabilized weight created successfully."
    di as text "{hline 70}"
    di as text "Exposure variable        : " as result "`trt'"
    di as text "Covariates               :" as result "`covars'"
    di as text "Denominator method       : " as result cond("`method'"=="firthlogit", "firthlogit + FLIC", "`method'")
    di as text "Numerator method         : " as result "intercept-only logit"
    di as text "Denominator PS variable  : " as result "`psden'"
    di as text "Numerator PS variable    : " as result "`psnum'"
    di as text "Weight variable          : " as result "`sw'"
    di as text "{hline 70}"
    di as text "Initial analysis sample N      : " as result `N0'
    di as text "Denominator model N            : " as result `Nden'
    di as text "Final weighted N               : " as result `Nfinal'
    di as text "Missing SW in full data        : " as result `Nmiss_all'
    di as text "Missing SW in analysis sample  : " as result `Nmiss_touse'
    di as text "{hline 70}"

    if "`method'" == "firthlogit" {
        di as text "FLIC check: observed Pr(`trt'=1), denominator sample : " as result %10.6f `trt_mean_den'
        di as text "FLIC check: mean FLIC denominator PS                 : " as result %10.6f `psden_mean_flic'
    }

    di as text _newline "Summary of stabilized weight:"
    di as text "Mean = " as result %10.4f `sw_mean' ///
       as text "    Min = " as result %10.4f `sw_min' ///
       as text "    Max = " as result %10.4f `sw_max'

    di as text _newline "Summary of stabilized weight by exposure group:"
    tabstat `sw' if `sample_final', by(`trt') ///
        statistics(n mean min max) ///
        columns(statistics) format(%10.4f)

    *------------------------------------------------------------
    * Return values
    *------------------------------------------------------------

    return scalar N_initial = `N0'
    return scalar N_denominator = `Nden'
    return scalar N_final = `Nfinal'
    return scalar N_missing_all = `Nmiss_all'
    return scalar N_missing_analysis_sample = `Nmiss_touse'
    return scalar sw_mean = `sw_mean'
    return scalar sw_min = `sw_min'
    return scalar sw_max = `sw_max'


    if "`method'" == "firthlogit" {
        return scalar trt_mean_den = `trt_mean_den'
        return scalar psden_mean_flic = `psden_mean_flic'
    }

    return local exposure `trt'
    return local covariates `covars'
    return local method `method'
    return local den_method `=cond("`method'"=="firthlogit", "firthlogit + FLIC", "`method'")'
    return local num_method "intercept-only logit"
    return local psden `psden'
    return local psnum `psnum'
    return local sw `sw'

end