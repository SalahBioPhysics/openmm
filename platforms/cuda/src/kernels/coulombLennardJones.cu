{
#if USE_EWALD
    bool needCorrection = hasExclusions && isExcluded && atom1 != atom2 && atom1 < NUM_ATOMS && atom2 < NUM_ATOMS;
    unsigned int includeInteraction = ((!isExcluded && r2 < CUTOFF_SQUARED) || needCorrection);
    const real alphaR = EWALD_ALPHA*r;
    const real expAlphaRSqr = EXP(-alphaR*alphaR);
    const real prefactor = 138.935456f*posq1.w*posq2.w*invR;

#ifdef USE_DOUBLE_PRECISION
    const real erfcAlphaR = erfc(alphaR);
#else
    // This approximation for erfc is from Abramowitz and Stegun (1964) p. 299.  They cite the following as
    // the original source: C. Hastings, Jr., Approximations for Digital Computers (1955).  It has a maximum
    // error of 1.5e-7.

    const real t = RECIP(1.0f+0.3275911f*alphaR);
    const real erfcAlphaR = (0.254829592f+(-0.284496736f+(1.421413741f+(-1.453152027f+1.061405429f*t)*t)*t)*t)*t*expAlphaRSqr;
#endif
    real tempForce = 0.0f;
    if (needCorrection) {
        // Subtract off the part of this interaction that was included in the reciprocal space contribution.

        if (1-erfcAlphaR > 1e-6) {
            real erfAlphaR = ERF(alphaR); // Our erfc approximation is not accurate enough when r is very small, which happens with Drude particles.
            tempForce = -prefactor*(erfAlphaR-alphaR*expAlphaRSqr*TWO_OVER_SQRT_PI);
            tempEnergy += -prefactor*erfAlphaR;
        }
        else {
            includeInteraction = false;
            tempEnergy -= TWO_OVER_SQRT_PI*EWALD_ALPHA*138.935456f*posq1.w*posq2.w;
        }
    }
    else {
#if HAS_LENNARD_JONES
        real sig = sigmaEpsilon1.x + sigmaEpsilon2.x;
        real sig2 = invR*sig;
        sig2 *= sig2;
        real sig6 = sig2*sig2*sig2;
        real epssig6 = sig6*(sigmaEpsilon1.y*sigmaEpsilon2.y);
        tempForce = epssig6*(12.0f*sig6 - 6.0f);
        real ljEnergy = epssig6*(sig6 - 1.0f);
        #if USE_LJ_SWITCH
        if (r > LJ_SWITCH_CUTOFF) {
            real x = r-LJ_SWITCH_CUTOFF;
            real switchValue = 1+x*x*x*(LJ_SWITCH_C3+x*(LJ_SWITCH_C4+x*LJ_SWITCH_C5));
            real switchDeriv = x*x*(3*LJ_SWITCH_C3+x*(4*LJ_SWITCH_C4+x*5*LJ_SWITCH_C5));
            tempForce = tempForce*switchValue - ljEnergy*switchDeriv*r;
            ljEnergy *= switchValue;
        }
        #endif
        tempForce += prefactor*(erfcAlphaR+alphaR*expAlphaRSqr*TWO_OVER_SQRT_PI);
        tempEnergy += includeInteraction ? ljEnergy + prefactor*erfcAlphaR : 0;
#else
        tempForce = prefactor*(erfcAlphaR+alphaR*expAlphaRSqr*TWO_OVER_SQRT_PI);
        tempEnergy += includeInteraction ? prefactor*erfcAlphaR : 0;
#endif
    }
    dEdR += includeInteraction ? tempForce*invR*invR : 0;
#else
#ifdef USE_CUTOFF
    unsigned int includeInteraction = (!isExcluded && r2 < CUTOFF_SQUARED);
#else
    unsigned int includeInteraction = (!isExcluded);
#endif
    real tempForce = 0.0f;
  #if HAS_LENNARD_JONES
    real sig = sigmaEpsilon1.x + sigmaEpsilon2.x;
    real sig2 = invR*sig;
    sig2 *= sig2;
    real sig6 = sig2*sig2*sig2;
    real epssig6 = sig6*(sigmaEpsilon1.y*sigmaEpsilon2.y);
    tempForce = epssig6*(12.0f*sig6 - 6.0f);
    real ljEnergy = includeInteraction ? epssig6*(sig6 - 1) : 0;
    #if USE_LJ_SWITCH
    if (r > LJ_SWITCH_CUTOFF) {
        real x = r-LJ_SWITCH_CUTOFF;
        real switchValue = 1+x*x*x*(LJ_SWITCH_C3+x*(LJ_SWITCH_C4+x*LJ_SWITCH_C5));
        real switchDeriv = x*x*(3*LJ_SWITCH_C3+x*(4*LJ_SWITCH_C4+x*5*LJ_SWITCH_C5));
        tempForce = tempForce*switchValue - ljEnergy*switchDeriv*r;
        ljEnergy *= switchValue;
    }
    #endif
    tempEnergy += ljEnergy;
  #endif
#if HAS_COULOMB
  #ifdef USE_CUTOFF
    const real prefactor = 138.935456f*posq1.w*posq2.w;
    tempForce += prefactor*(invR - 2.0f*REACTION_FIELD_K*r2);
    tempEnergy += includeInteraction ? prefactor*(invR + REACTION_FIELD_K*r2 - REACTION_FIELD_C) : 0;
  #else
    const real prefactor = 138.935456f*posq1.w*posq2.w*invR;
    tempForce += prefactor;
    tempEnergy += includeInteraction ? prefactor : 0;
  #endif
#endif
    dEdR += includeInteraction ? tempForce*invR*invR : 0;
#endif
}
