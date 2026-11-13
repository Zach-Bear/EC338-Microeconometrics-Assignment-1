*==============================================================================
* EC338 Assignment 1 -- Group 25 -- Albania (HBSC 2014, 2018, 2022)
*
* Question: do (i) the gender of a student's siblings and (ii) the gender mix of
* the student's class affect adolescents' mental health?
*
* This one file takes the ORIGINAL HBSC files and produces every table and figure.
*
*   PART 1  Build the dataset      (take Albania out of each wave, line the waves up)
*   PART 2  Descriptive statistics (Table 1)
*   PART 3  Is assignment random?  (balance tests, benchmark, class-balance figure)
*   PART 4  Headline results       (main tables, one per wave, then the pooled models)
*   PART 5  Appendix checks        (robustness, subgroups, mechanisms, ordered probit,
*                                   small-category checks)
*
* HEADLINE SPECIFICATION (this is what the paper's main tables report)
*   Outcomes   : psychological complaints index (feeling low, irritable, nervous;
*                higher = worse) and life satisfaction (0-10; higher = better).
*                Both are standardised within each wave, so effects are in
*                standard deviations of that wave's outcome.
*   Treatments : (i)  share of brothers among a student's siblings (2014, 2022)
*                (ii) share of girls among a student's classmates (2014, 2018, 2022)
*                2018 has no sibling questions at all.
*   Model      : OLS with own sex, age group, number of siblings (sibling model) or
*                class size (class model), family affluence and parents' employment.
*                Standard errors are clustered by class.
*   Identification check: the same model with school-by-age-group fixed effects,
*                which compares classes within the same school and age group.
*==============================================================================
clear all
set more off

*---- Folders: change these two lines, nothing else needs editing -----------------
global raw "C:/Users/zedbe/Downloads/Allrounds_STATA_v8_1"          // folder with the original HBSC .dta files
global out "C:/Users/zedbe/Downloads/Allrounds_STATA_v8_1/results"  // results go here (created if missing)
*----------------------------------------------------------------------------------

cap mkdir "$out"
cap mkdir "$out/tables"
cap mkdir "$out/figures"
cap log close _all
log using "$out/EC338_Group25_CountryAlbania.log", replace text    // if Stata says the log is locked, close it in other programs first
set seed 338                                                       // makes the random-class simulation repeatable
cap which esttab
if _rc ssc install estout, replace                                 // package that writes the tables

* How the tables are printed: "show" is for the log, "tex" is for the LaTeX files.
local show "se b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) stats(N, fmt(0))"
local tex  "`show' booktabs"


*==============================================================================
* PART 1. BUILD THE DATASET
*==============================================================================

* 1.1 Take Albania out of each original file, rename the variables so the three
*     waves match, and stack the waves into one dataset (one row per student).

local file2014 "HBSC2014OAed2.0"
local file2018 "HBSC2018OAed1.1"
local file2022 "HBSC2022OAed1.0"

* The variables we keep from every wave. Suggest more.
local keepvars wave id1 id2 id3 sex agecat grade brothers sisters                ///
    feellow irritable nervous sleepdifficulty lifesat                              ///
    fasfamcar fasbedroom fascomputers fasbathroom fasdishwash fasholidays          ///
    employfa employmo mfses mmses                                                  ///
    talkmother talkfather beenbullied studtogether studhelpful studaccept likeschool

tempfile w2014 w2018 w2022
foreach w in 2014 2018 2022 {
    use "$raw/`file`w''.dta", clear

    * make all variable names lower case so the waves match
	rename *, lower
	
    cap rename sleepdificulty sleepdifficulty      // the original files misspell this variable i kid you not

    * keep only Albania, same no in each wave
	keep if countryno == 8000
    gen wave = `w'

    * Siblings living in the student's main home. The variable names differ by wave,
    * and the 2018 survey did not ask the question at all.
    if `w' == 2014 {
        gen brothers = brothershome1
        gen sisters  = sistershome1
    }
    else if `w' == 2022 {
        gen brothers = brothernum
        gen sisters  = sisternum
    }
    else {
        gen brothers = . // this is how you code/create missing values in stata, will use a lot.
        gen sisters  = .
    }

    * A variable that a wave does not have is created empty, so the waves can be stacked without data spilling into the wrong columns.
    foreach v of local keepvars {
        cap confirm variable `v'
        if _rc gen `v' = .
    }
    keep `keepvars'
    save `w`w'', replace
}
use `w2014', clear // 'w' for wave, 'v' for variable. Will try to keep consistent placeholders.
append using `w2018' `w2022'

* 1.2 Identifiers: a class number that is unique across waves, and a school number.
* There may be a better way to do this but I was proud of this way.
* I'm not proud of HBSC repeating school numbers within waves, why?
gen long classid = wave*100000 + id3
* The school code is municipality x school number. A few pupils have a different school
* code from their classmates, so each class is given its most common school code.
* This only happens in 2014 and 2018 suggesting it was a misreading issue or typo that got
* fixed with later iterations of the questionnaire.
gen school_code = id1*1000 + id2
bys classid: egen school_mode = mode(school_code), minmode // tiebreaks with minimum code
egen school = group(wave school_mode)

* 1.3 The student's own characteristics
gen girl = (sex == 2) if !missing(sex)
* Age group: HBSC's own age category (11, 13, 15). Where it is missing, use school grade.
gen age_grp = agecat
replace age_grp = grade if missing(agecat)
label define agelabel 1 "Age 11" 2 "Age 13" 3 "Age 15"
label values age_grp agelabel
egen school_age = group(school age_grp)       // used for the school-by-age-group comparison

* 1.4 Outcomes
* The symptom questions run 1 = about every day ... 5 = rarely or never.
* Reverse them (6 minus the answer) so that HIGHER means MORE complaints.
foreach v in feellow irritable nervous sleepdifficulty {
    gen rev_`v' = 6 - `v'
}
* Main index: average of feeling low, irritable, nervous (needs at least 2 of the 3 answers)
egen items3 = rownonmiss(rev_feellow rev_irritable rev_nervous)
egen index3 = rowmean(rev_feellow rev_irritable rev_nervous)
replace index3 = . if items3 < 2
* Robustness index: also includes sleep difficulties (needs at least 3 of the 4 answers)
egen items4 = rownonmiss(rev_feellow rev_irritable rev_nervous rev_sleepdifficulty)
egen index4 = rowmean(rev_feellow rev_irritable rev_nervous rev_sleepdifficulty)
replace index4 = . if items4 < 3
* Standardise within each wave (mean 0, standard deviation 1)
bys wave: egen complaints3 = std(index3)
bys wave: egen complaints4 = std(index4)
bys wave: egen lifesat_z   = std(lifesat)
label var complaints3 "Psychological complaints (3 items, z-score)"
label var complaints4 "Psychological complaints (4 items, z-score)"
label var lifesat_z   "Life satisfaction (z-score)"

* 1.5 Controls that exist in every wave
* Family affluence: average of six standardised items (car, own bedroom, computers,
* bathrooms, dishwasher, holidays). Needs at least 5 of the 6 answers.
foreach v in fasfamcar fasbedroom fascomputers fasbathroom fasdishwash fasholidays {
    bys wave: egen z_`v' = std(`v')
}
egen items_fas = rownonmiss(z_fasfamcar z_fasbedroom z_fascomputers z_fasbathroom z_fasdishwash z_fasholidays)
egen fas_z = rowmean(z_fasfamcar z_fasbedroom z_fascomputers z_fasbathroom z_fasdishwash z_fasholidays)
replace fas_z = . if items_fas < 5
label var fas_z "Family affluence (z-score)"

* Parents' employment: 1 = works, 2 = does not work, 3 or 4 = don't know / don't have.
* Missing answers are kept as their own category (9) so nobody is dropped.
gen emo = employmo
gen efa = employfa
replace emo = 9 if missing(emo)
replace efa = 9 if missing(efa)
gen momwork = (employmo == 1) if inlist(employmo, 1, 2)
gen dadwork = (employfa == 1) if inlist(employfa, 1, 2)
* Version with the rare categories merged: works / does not work / unknown
gen emo3 = cond(employmo == 1, 1, cond(employmo == 2, 2, 3))
gen efa3 = cond(employfa == 1, 1, cond(employfa == 2, 2, 3))
* Parents' occupation exists in 2014 only, so it can be used only as an extra check for 2014
gen father_occ = mfses
gen mother_occ = mmses
replace father_occ = 99 if missing(father_occ)
replace mother_occ = 99 if missing(mother_occ)

* 1.6 Treatment (i): sibling gender
gen nsib      = brothers + sisters
gen sibsample = inrange(nsib, 1, 4)           // only-childs have no siblings to compare; 5+ is rare
gen share_bro = brothers / nsib if sibsample
label var share_bro "Share of brothers among siblings"

* 1.7 Treatment (ii): class gender composition
* n_class is the number of students from the class WE observe (not the real class size).
bys classid: egen n_class   = count(girl)
bys classid: egen girls_cls = total(girl)
* Share of girls among the OTHER students in the class (the student themself is left out),
* only for classes with at least 5 respondents.
gen share_girls_cls = (girls_cls - girl) / (n_class - 1) if n_class >= 5 & !missing(girl)
label var share_girls_cls "Share of girls among classmates"

* 1.8 Mechanism questions. Higher = worse for all of them (harder to talk to a parent,
* more bullied, LESS classmate support, likes school less). Standardised within wave.
replace talkmother = . if talkmother == 5      // 5 = "don't have or see this parent"
replace talkfather = . if talkfather == 5
foreach v in talkmother talkfather beenbullied likeschool studtogether studhelpful studaccept {
    bys wave: egen z_`v' = std(`v')
}
egen z_studsupport = rowmean(z_studtogether z_studhelpful z_studaccept)

* 1.9 The two estimation samples (ensure the students have the same data)
gen s_sib = sibsample & !missing(girl, age_grp, fas_z, share_bro)
gen s_cls = !missing(girl, age_grp, fas_z, share_girls_cls, n_class)

compress
save "$out/hbsc_albania_pooled.dta", replace
di _n "Albania observations by wave:"
tab wave
di _n "Students in the sibling analysis / class analysis, by wave:"
tab wave s_sib
tab wave s_cls

* Useful macros for controls used in the regressions henceforth
global SIB_MIN "girl i.age_grp i.nsib"
global SIB     "$SIB_MIN fas_z i.emo i.efa"
global CLS_MIN "girl i.age_grp c.n_class"
global CLS     "$CLS_MIN fas_z i.emo i.efa"


*==============================================================================
* PART 2. DESCRIPTIVE STATISTICS (Table 1)
*==============================================================================
eststo clear
foreach w in 2014 2018 2022 {
    eststo D`w': quietly estpost summarize girl complaints3 lifesat nsib share_bro share_girls_cls ///
        n_class fas_z momwork dadwork if wave == `w'
}
esttab D2014 D2018 D2022 using "$out/tables/T1_descriptives.tex", replace booktabs ///
    cells("count mean(fmt(2)) sd(fmt(2))") mtitles("2014" "2018" "2022") nonumber ///
    title("Descriptive statistics by wave")
esttab D2014 D2018 D2022, cells("count mean(fmt(2)) sd(fmt(2))") mtitles("2014" "2018" "2022") nonumber


*==============================================================================
* PART 3. RANDOM ASSIGNMENT BALANCE TESTS
*==============================================================================
*WE PROBABLY WANT TO MERGE 3.1 and 3.2 INTO ONE TABLE IN THE APPENDIX IT WOULD LOOK NICER.

*---- 3.1 Sibling gender (2014 and 2022) -----------------------------------------
* If sibling gender were random: (a) about 51.2% of babies are boys, so the average
* number of brothers should be about 0.512 times the number of siblings; (b) it should
* not depend on the student's own sex or on family characteristics.
foreach w in 2014 2022 {
    di _n "---- Sibling gender, wave `w' ----"
    forvalues n = 1/4 {
        quietly summ brothers if s_sib & wave == `w' & nsib == `n'
        di "Families with `n' sibling(s): N = " r(N) ", mean brothers = " %5.3f r(mean) ", expected = " %5.3f `n'*0.512
    }
    cap drop one_sib_bro
    gen byte one_sib_bro = (brothers > 0) if s_sib & wave == `w' & nsib == 1
    di "Share of one-sibling families with a brother, tested against 0.512:"
    prtest one_sib_bro == 0.512
    drop one_sib_bro

    * Does the share of brothers predict other (predetermined) characteristics?
    eststo clear
    foreach x in girl fas_z momwork dadwork {
        eststo B_`x': quietly reg `x' share_bro i.age_grp i.nsib if s_sib & wave == `w', vce(cluster classid)
    }
    if `w' == 2014 {
        foreach x in mfses mmses {
            eststo B_`x': quietly reg `x' share_bro i.age_grp i.nsib if s_sib & wave == `w', vce(cluster classid)
        }
    }
    esttab B_* using "$out/tables/T2_balance_siblings_`w'.tex", replace `tex' keep(share_bro) ///
        title("Balance test: share of brothers, `w'")
    di "Joint test: do own sex, affluence and parents' work predict the share of brothers?"
    quietly reg share_bro girl fas_z momwork dadwork i.age_grp i.nsib if s_sib & wave == `w', vce(cluster classid)
    testparm girl fas_z momwork dadwork
}

*---- 3.2 Class gender composition (2014, 2018, 2022) ------------------------------
* If classes were formed at random: (a) family characteristics should not predict the
* share of girls; (b) classes should differ in their share of girls by about as much as
* random draws would (we simulate this below).
tempfile base pos gl
foreach w in 2014 2018 2022 {
    di _n "---- Class composition, wave `w' ----"
    eststo clear
    foreach x in fas_z momwork dadwork {
        eststo K_`x': quietly reg `x' share_girls_cls girl i.age_grp c.n_class if s_cls & wave == `w', vce(cluster classid)
    }
    esttab K_* using "$out/tables/T3_balance_class_`w'.tex", replace `tex' keep(share_girls_cls) ///
        title("Balance test: share of girls among classmates, `w'")
    di "Joint test: do affluence and parents' work predict the share of girls?"
    quietly reg share_girls_cls girl fas_z momwork dadwork i.age_grp c.n_class if s_cls & wave == `w', vce(cluster classid)
    testparm fas_z momwork dadwork
    di "Does a student's own sex predict the share of girls among classmates? (about zero if random)"
    reg share_girls_cls girl i.age_grp c.n_class if s_cls & wave == `w', vce(cluster classid)

    * Simulation: keep every class the same size but shuffle students' sex at random
    * (within age group) 500 times. Compare how much classes differ in their share of girls
    * in the real data with the same spread in the shuffled data.
    preserve
        quietly {
            keep if wave == `w' & n_class >= 5 & !missing(girl, age_grp)
            keep classid age_grp girl
            save `base', replace
            collapse (mean) cs = girl, by(classid)
            summ cs
            local real_sd = r(sd)
            use `base', clear
            sort age_grp classid
            by age_grp: gen slot = _n
            keep age_grp classid slot
            save `pos', replace
            use `base', clear
            keep age_grp girl
            save `gl', replace
            tempname sim
            postfile `sim' sd using "$out/sim_sd_`w'.dta", replace
            forvalues r = 1/500 {
                use `gl', clear
                gen u = runiform()
                sort age_grp u
                by age_grp: gen slot = _n
                merge m:1 age_grp slot using `pos', nogen keep(match)
                collapse (mean) cs = girl, by(classid)
                summ cs
                post `sim' (r(sd))
            }
            postclose `sim'
            use "$out/sim_sd_`w'.dta", clear
            summ sd
            local random_sd = r(mean)
            count if sd <= `real_sd'
            local share_below = r(N)/500
            count if sd >= `real_sd'
            local share_above = r(N)/500
        }
        di "Wave `w': real spread of class share girls = " %5.3f `real_sd' ", random-allocation spread = " %5.3f `random_sd' ///
           ". Shuffled runs with a smaller spread: " %4.2f `share_below' "; with a larger spread: " %4.2f `share_above' "."
        hist sd, xline(`real_sd') xscale(range(0.08 0.28)) xlabel(0.08(0.04)0.28) xtitle("Spread (SD) of class share girls") ///
            title("`w': shuffled classes (bars) vs real classes (line)")
        graph export "$out/figures/Fig1_class_balance_`w'.png", replace width(1200)
    restore
}


*==============================================================================
* PART 4. HEADLINE RESULTS
* Each table has three columns per outcome:
*   (1) minimal controls   (2) HEADLINE specification   (3) HEADLINE + school-by-age FE
* Standard errors are clustered by class. Effects are in standard deviations of the outcome.
*==============================================================================

*---- 4.1 Sibling gender, 2014 and 2022 ---------------------------------------------
foreach w in 2014 2022 {
    di _n "######## SIBLING GENDER, `w' ########"
    eststo clear
    foreach y in complaints3 lifesat_z {
        eststo S1_`y': quietly reg `y' share_bro $SIB_MIN if s_sib & wave == `w', vce(cluster classid)
        eststo S2_`y': quietly reg `y' share_bro $SIB if s_sib & wave == `w', vce(cluster classid)
        if "`y'" == "complaints3" di "Smallest effect we could reliably detect (80% power), all sisters -> all brothers: " %5.3f 2.8*_se[share_bro]
        eststo S3_`y': quietly areg `y' share_bro girl i.nsib fas_z i.emo i.efa if s_sib & wave == `w', ///
            absorb(school_age) vce(cluster classid)
    }
    esttab S*_complaints3 S*_lifesat_z using "$out/tables/T4_siblings_`w'.tex", replace `tex' keep(share_bro) ///
        mtitles("Compl. (1)" "Compl. (2)" "Compl. (3)" "Life sat. (1)" "Life sat. (2)" "Life sat. (3)") ///
        title("Sibling gender and mental health, `w'")
    esttab S*_complaints3 S*_lifesat_z, `show' keep(share_bro) ///
        mtitles("Compl. (1)" "Compl. (2)" "Compl. (3)" "Life sat. (1)" "Life sat. (2)" "Life sat. (3)")
}

*---- 4.2 Class gender composition, 2014, 2018 and 2022 -------------------------------
foreach w in 2014 2018 2022 {
    di _n "######## CLASS COMPOSITION, `w' ########"
    eststo clear
    foreach y in complaints3 lifesat_z {
        eststo C1_`y': quietly reg `y' share_girls_cls $CLS_MIN if s_cls & wave == `w', vce(cluster classid)
        eststo C2_`y': quietly reg `y' share_girls_cls $CLS if s_cls & wave == `w', vce(cluster classid)
        if "`y'" == "complaints3" {
            quietly summ share_girls_cls if e(sample)
            di "Smallest effect we could reliably detect (80% power): " %5.3f 2.8*_se[share_girls_cls] ///
               " for 0% -> 100% girls, or " %5.3f 2.8*_se[share_girls_cls]*r(sd) " for a one-standard-deviation change in the share"
        }
        eststo C3_`y': quietly areg `y' share_girls_cls girl c.n_class fas_z i.emo i.efa if s_cls & wave == `w', ///
            absorb(school_age) vce(cluster classid)
    }
    esttab C*_complaints3 C*_lifesat_z using "$out/tables/T5_class_`w'.tex", replace `tex' keep(share_girls_cls) ///
        mtitles("Compl. (1)" "Compl. (2)" "Compl. (3)" "Life sat. (1)" "Life sat. (2)" "Life sat. (3)") ///
        title("Class gender composition and mental health, `w'")
    esttab C*_complaints3 C*_lifesat_z, `show' keep(share_girls_cls) ///
        mtitles("Compl. (1)" "Compl. (2)" "Compl. (3)" "Life sat. (1)" "Life sat. (2)" "Life sat. (3)")
}

*---- 4.3 Pooled models: do the waves tell the same story? -------------------------
* The effect is allowed to differ by wave (one coefficient per wave). Wave dummies, and
* wave-specific own-sex effects, are included. The "test" lines ask whether the wave
* effects are equal; if they are not, report the wave-specific effects, not an average.
gen bro_2014   = share_bro * (wave == 2014)
gen bro_2022   = share_bro * (wave == 2022)
gen girls_2014 = share_girls_cls * (wave == 2014)
gen girls_2018 = share_girls_cls * (wave == 2018)
gen girls_2022 = share_girls_cls * (wave == 2022)

di _n "######## POOLED MODELS ########"
eststo clear
foreach y in complaints3 lifesat_z {
    eststo PS_`y':  quietly reg `y' bro_2014 bro_2022 i.wave##i.girl i.age_grp i.nsib fas_z i.emo i.efa ///
        if s_sib & inlist(wave, 2014, 2022), vce(cluster classid)
    di "`y': sibling effect equal in 2014 and 2022?"
    test bro_2014 = bro_2022
    eststo PSc_`y': quietly reg `y' share_bro i.wave##i.girl i.age_grp i.nsib fas_z i.emo i.efa ///
        if s_sib & inlist(wave, 2014, 2022), vce(cluster classid)
    eststo PC_`y':  quietly reg `y' girls_2014 girls_2018 girls_2022 i.wave##i.girl i.age_grp c.n_class fas_z i.emo i.efa ///
        if s_cls, vce(cluster classid)
    di "`y': class-composition effect equal in all three waves?"
    test (girls_2014 = girls_2018) (girls_2018 = girls_2022)
    eststo PCc_`y': quietly reg `y' share_girls_cls i.wave##i.girl i.age_grp c.n_class fas_z i.emo i.efa ///
        if s_cls, vce(cluster classid)
}
esttab PS_* PSc_* using "$out/tables/T6_pooled_siblings.tex", replace `tex' keep(bro_2014 bro_2022 share_bro) ///
    title("Pooled models: sibling gender")
esttab PC_* PCc_* using "$out/tables/T7_pooled_class.tex", replace `tex' keep(girls_2014 girls_2018 girls_2022 share_girls_cls) ///
    title("Pooled models: class composition")
esttab PS_* PSc_*, `show' keep(bro_2014 bro_2022 share_bro)
esttab PC_* PCc_*, `show' keep(girls_2014 girls_2018 girls_2022 share_girls_cls)


*==============================================================================
* PART 5. APPENDIX CHECKS (none of these change the headline results)
*==============================================================================
* THIS IS LARGELY GOING IN THE APPENDIX AND I HAVE TO ADMIT I DO NOT FULLY UNDERSTAND IT

*---- 5.1 Both treatments in one regression (2014 and 2022) ---------------------------
* The headline models study the two treatments separately because they involve different
* samples and different problems. This checks that putting them together changes little.
eststo clear
foreach w in 2014 2022 {
    foreach y in complaints3 lifesat_z {
        eststo J`w'_`y': quietly reg `y' share_bro share_girls_cls girl i.age_grp i.nsib c.n_class fas_z i.emo i.efa ///
            if s_sib & s_cls & wave == `w', vce(cluster classid)
    }
}
esttab J* using "$out/tables/A1_joint_model.tex", replace `tex' keep(share_bro share_girls_cls) ///
    title("Both treatments in one model")

*---- 5.2 Robustness of the headline model ------------------------------------------------
eststo clear
foreach w in 2014 2018 2022 {
    * (a) complaints index with sleep difficulties added
    if `w' != 2018 eststo Ra_s`w': quietly reg complaints4 share_bro $SIB if s_sib & wave == `w', vce(cluster classid)
    eststo Ra_c`w': quietly reg complaints4 share_girls_cls $CLS if s_cls & wave == `w', vce(cluster classid)
    * (b) standard errors clustered by school instead of class
    if `w' != 2018 eststo Rb_s`w': quietly reg complaints3 share_bro $SIB if s_sib & wave == `w', vce(cluster school)
    eststo Rb_c`w': quietly reg complaints3 share_girls_cls $CLS if s_cls & wave == `w', vce(cluster school)
    * (c) class share based on at least 8 respondents (less noisy)
    eststo Rc_c`w': quietly reg complaints3 share_girls_cls $CLS if s_cls & n_class >= 8 & wave == `w', vce(cluster classid)
}
* (d) 2014 only: add father's and mother's occupation
eststo Rd_s2014: quietly reg complaints3 share_bro $SIB i.father_occ i.mother_occ if s_sib & wave == 2014, vce(cluster classid)
eststo Rd_c2014: quietly reg complaints3 share_girls_cls $CLS i.father_occ i.mother_occ if s_cls & wave == 2014, vce(cluster classid)
esttab Ra_* Rb_* Rc_* Rd_* using "$out/tables/A2_robustness.tex", replace `tex' keep(share_bro share_girls_cls) ///
    title("Robustness: (a) 4-item index, (b) school clusters, (c) classes with 8+ respondents, (d) parents' occupation, 2014")

*---- 5.3 Do effects differ by own sex or by age group? ----------------------------------
* Own sex: the main coefficient is the effect for boys; the "girl#" line is how much
* the effect for girls differs. "lincom" prints the total effect for girls.
foreach w in 2014 2018 2022 {
    di _n "######## EFFECTS BY OWN SEX, `w' ########"
    eststo clear
    foreach y in complaints3 lifesat_z {
        if `w' != 2018 {
            eststo HS_`y': quietly reg `y' c.share_bro##i.girl i.age_grp i.nsib fas_z i.emo i.efa ///
                if s_sib & wave == `w', vce(cluster classid)
            di "Sibling gender, `y': effect for girls"
            lincom share_bro + 1.girl#c.share_bro
        }
        eststo HC_`y': quietly reg `y' c.share_girls_cls##i.girl i.age_grp c.n_class fas_z i.emo i.efa ///
            if s_cls & wave == `w', vce(cluster classid)
        di "Class composition, `y': effect for girls"
        lincom share_girls_cls + 1.girl#c.share_girls_cls
    }
    if `w' != 2018 {
        esttab HS_* using "$out/tables/A3_by_sex_siblings_`w'.tex", replace `tex' keep(share_bro 1.girl#c.share_bro) ///
            title("Sibling gender by own sex, `w'")
    }
    esttab HC_* using "$out/tables/A3_by_sex_class_`w'.tex", replace `tex' keep(share_girls_cls 1.girl#c.share_girls_cls) ///
        title("Class composition by own sex, `w'")
}

* Age group (not done for 2018: only 289 students there are aged 13)
foreach w in 2014 2022 {
    di _n "######## EFFECTS BY AGE GROUP, `w' ########"
    eststo clear
    foreach y in complaints3 lifesat_z {
        forvalues g = 1/3 {
            eststo AS`g'_`y': quietly reg `y' share_bro girl i.nsib fas_z i.emo i.efa ///
                if s_sib & wave == `w' & age_grp == `g', vce(cluster classid)
        }
        quietly reg `y' c.share_bro##i.age_grp girl i.nsib fas_z i.emo i.efa if s_sib & wave == `w', vce(cluster classid)
        di "Sibling gender, `y': do the three age effects differ?"
        testparm i.age_grp#c.share_bro
    }
    esttab AS* using "$out/tables/A4_by_age_siblings_`w'.tex", replace `tex' keep(share_bro) ///
        mtitles("Compl. 11" "Compl. 13" "Compl. 15" "Life sat. 11" "Life sat. 13" "Life sat. 15") ///
        title("Sibling gender by age group, `w'")
    eststo clear
    foreach y in complaints3 lifesat_z {
        forvalues g = 1/3 {
            eststo AC`g'_`y': quietly reg `y' share_girls_cls girl c.n_class fas_z i.emo i.efa ///
                if s_cls & wave == `w' & age_grp == `g', vce(cluster classid)
        }
        quietly reg `y' c.share_girls_cls##i.age_grp girl c.n_class fas_z i.emo i.efa if s_cls & wave == `w', vce(cluster classid)
        di "Class composition, `y': do the three age effects differ?"
        testparm i.age_grp#c.share_girls_cls
    }
    esttab AC* using "$out/tables/A4_by_age_class_`w'.tex", replace `tex' keep(share_girls_cls) ///
        mtitles("Compl. 11" "Compl. 13" "Compl. 15" "Life sat. 11" "Life sat. 13" "Life sat. 15") ///
        title("Class composition by age group, `w'")
}

*---- 5.4 Possible channels (mechanisms) ----------------------------------------------------
* For all five outcomes, HIGHER = WORSE (harder to talk to a parent, more bullied,
* less classmate support, likes school less), so a negative coefficient is "better".
foreach w in 2014 2018 2022 {
    eststo clear
    foreach m in z_talkmother z_talkfather z_beenbullied z_studsupport z_likeschool {
        if `w' != 2018 eststo MS_`m': quietly reg `m' share_bro $SIB if s_sib & wave == `w', vce(cluster classid)
        eststo MC_`m': quietly reg `m' share_girls_cls $CLS if s_cls & wave == `w', vce(cluster classid)
    }
    if `w' != 2018 {
        esttab MS_* using "$out/tables/A5_mechanisms_siblings_`w'.tex", replace `tex' keep(share_bro) ///
            title("Channels: sibling gender, `w'")
    }
    esttab MC_* using "$out/tables/A5_mechanisms_class_`w'.tex", replace `tex' keep(share_girls_cls) ///
        title("Channels: class composition, `w'")
}

*---- 5.5 Ordered probit ---------------------------------------------------------------------
* Ordinary regression treats answers such as "never ... every day" as equally spaced numbers.
* Ordered probit only uses their order. If both agree, the equal-spacing assumption is not
* driving the results. It needs whole-number answers, so it is run on the three symptom
* questions one at a time and on life satisfaction (not on the averaged index).
foreach w in 2014 2022 {
    eststo clear
    foreach y in rev_feellow rev_irritable rev_nervous lifesat {
        eststo ols_`y': quietly reg `y' share_bro $SIB if s_sib & wave == `w', vce(cluster classid)
        eststo oprobit_`y': quietly oprobit `y' share_bro $SIB if s_sib & wave == `w', vce(cluster classid)
    }
    esttab ols_* oprobit_* using "$out/tables/A6_oprobit_siblings_`w'.tex", replace `tex' keep(share_bro) ///
        title("Sibling gender: OLS and ordered probit, `w'")
    quietly oprobit rev_feellow share_bro $SIB if s_sib & wave == `w', vce(cluster classid)
    di "Wave `w': change in the probability of feeling low EVERY DAY, all sisters -> all brothers:"
    margins, dydx(share_bro) predict(outcome(5))
}
foreach w in 2014 2018 2022 {
    eststo clear
    foreach y in rev_feellow rev_irritable rev_nervous lifesat {
        eststo ols_`y': quietly reg `y' share_girls_cls $CLS if s_cls & wave == `w', vce(cluster classid)
        eststo oprobit_`y': quietly oprobit `y' share_girls_cls $CLS if s_cls & wave == `w', vce(cluster classid)
    }
    esttab ols_* oprobit_* using "$out/tables/A6_oprobit_class_`w'.tex", replace `tex' keep(share_girls_cls) ///
        title("Class composition: OLS and ordered probit, `w'")
    quietly oprobit rev_feellow share_girls_cls $CLS if s_cls & wave == `w', vce(cluster classid)
    di "Wave `w': change in the probability of feeling low EVERY DAY, 0% -> 100% girls:"
    margins, dydx(share_girls_cls) predict(outcome(5))
}

*---- 5.6 Small categories (these can make estimates unstable) ---------------------------------
* Some answer categories contain very few students. Here is how many, and a check that the
* headline results survive when the small categories are merged or removed.
di _n "######## SMALL-CATEGORY COUNTS ########"
di "Parents' employment (categories 3, 4 and 9 are small): mother, then father"
tab emo wave
tab efa wave
di "Number of siblings (4 is small), sibling sample only:"
tab nsib wave if sibsample
di "Life satisfaction (scores 0 to 4 are small; the 2014 spike at 0 looks unusual):"
tab lifesat wave
di "Age group (age 13 in 2018 is small):"
tab age_grp wave

eststo clear
foreach w in 2014 2022 {
    * (a) parents' employment with the small categories merged (works / does not work / unknown)
    eststo Qa_s`w': quietly reg complaints3 share_bro girl i.age_grp i.nsib fas_z i.emo3 i.efa3 if s_sib & wave == `w', vce(cluster classid)
    * (b) families with at most 3 siblings (drops the small group with 4)
    eststo Qb_s`w': quietly reg complaints3 share_bro $SIB if s_sib & nsib <= 3 & wave == `w', vce(cluster classid)
    * (c) life satisfaction without students who answered 0
    eststo Qc_s`w': quietly reg lifesat_z share_bro $SIB if s_sib & lifesat > 0 & wave == `w', vce(cluster classid)
}
esttab Q* using "$out/tables/A7_small_categories_siblings.tex", replace `tex' keep(share_bro) ///
    title("Small-category checks: sibling gender")
eststo clear
foreach w in 2014 2018 2022 {
    eststo Qa_c`w': quietly reg complaints3 share_girls_cls girl i.age_grp c.n_class fas_z i.emo3 i.efa3 if s_cls & wave == `w', vce(cluster classid)
    eststo Qc_c`w': quietly reg lifesat_z share_girls_cls $CLS if s_cls & lifesat > 0 & wave == `w', vce(cluster classid)
}
esttab Q* using "$out/tables/A7_small_categories_class.tex", replace `tex' keep(share_girls_cls) ///
    title("Small-category checks: class composition")

di _n "Finished. Tables are in $out/tables, figures in $out/figures."
log close
