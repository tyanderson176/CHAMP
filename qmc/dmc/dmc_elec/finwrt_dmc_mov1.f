      subroutine finwrt_dmc_mov1 !JT
c Written by Cyrus Umrigar, modified by Claudia Filippi
c routine to print out final results

      use all_tools_mod  !JT
      use main_menu_mod  !JT

      implicit real*8(a-h,o-z)

!JT      parameter (one=1.d0,two=2.d0,half=.5d0)

      common /dim/ ndim
      common /forcepar/ deltot(MFORCE),nforce,istrech
      common /forcest/ fgcum(MFORCE),fgcm2(MFORCE)
c     common /force_dmc/ itausec,nwprod

      common /const/ pi,hb,etrial,delta,deltai,fbias,nelec,imetro,ipr
      common /contrl_per/ iperiodic,ibasis
      common /contrl/ nstep,nblk,nblkeq,nconf,nconf_new,isite,idump,irstar
      common /contr2/ ijas,icusp,icusp2,isc,inum_orb,ianalyt_lap
     &,ifock,i3body,irewgt,iaver,istrch
     &,ipos,idcds,idcdu,idcdt,id2cds,id2cdu,id2cdt,idbds,idbdu,idbdt
      common /contr3/ mode
      common /contrldmc/ tau,rttau,taueff(MFORCE),tautot,nfprod,idmc,ipq
     &,itau_eff,iacc_rej,icross,icuspg,idiv_v,icut_br,icut_e
      common /iterat/ ipass,iblk
      common /atom/ znuc(MCTYPE),cent(3,MCENT),pecent
     &,iwctype(MCENT),nctype,ncent
c /config_dmc/ included to print out xoldw and voldw for old walkers
      common /config_dmc/ xoldw(3,MELEC,MWALK,MFORCE),voldw(3,MELEC,MWALK,MFORCE),
     &psidow(MWALK,MFORCE),psijow(MWALK,MFORCE),peow(MWALK,MFORCE),peiow(MWALK,MFORCE),d2ow(MWALK,MFORCE)
      common /stats/ dfus2ac,dfus2un,dr2ac,dr2un,acc,acc_int,try_int,
     &nbrnch,nodecr
      common /estsum/ wsum,w_acc_sum,wfsum,wgsum(MFORCE),wg_acc_sum,wdsum,
     &wgdsum, wsum1(MFORCE),w_acc_sum1,wfsum1,wgsum1(MFORCE),wg_acc_sum1,
     &wdsum1, esum,efsum,egsum(MFORCE),esum1(MFORCE),efsum1,egsum1(MFORCE),
     &ei1sum,ei2sum,ei3sum, pesum(MFORCE),peisum(MFORCE),tpbsum(MFORCE),tjfsum(MFORCE),r2sum,
     &risum,tausum(MFORCE)
      common /estcum_dmc/ wcum,w_acc_cum,wfcum,wgcum(MFORCE),wg_acc_cum,wdcum,
     &wgdcum, wcum1,w_acc_cum1,wfcum1,wgcum1(MFORCE),wg_acc_cum1,
     &wdcum1, ecum,efcum,egcum(MFORCE),ecum1,efcum1,egcum1(MFORCE),
     &ei1cum,ei2cum,ei3cum, pecum(MFORCE),peicum(MFORCE),tpbcum(MFORCE),tjfcum(MFORCE),r2cum,
     &ricum,taucum(MFORCE)
      common /estcm2/ wcm2,wfcm2,wgcm2(MFORCE),wdcm2,wgdcm2, wcm21,
     &wfcm21,wgcm21(MFORCE),wdcm21, ecm2,efcm2,egcm2(MFORCE), ecm21,
     &efcm21,egcm21(MFORCE),ei1cm2,ei2cm2,ei3cm2, pecm2(MFORCE),peicm2(MFORCE),tpbcm2(MFORCE),
     &tjfcm2(MFORCE),r2cm2,ricm2
      common /stepv/ try(NRAD),suc(NRAD),trunfb(NRAD),rprob(NRAD),
     &ekin(NRAD),ekin2(NRAD)
      common /denupdn/ rprobup(NRAD),rprobdn(NRAD)
      common /branch/ wtgen(0:MFPRD1),ff(0:MFPRD1),eoldw(MWALK,MFORCE),
     &pwt(MWALK,MFORCE),wthist(MWALK,0:MFORCE_WT_PRD,MFORCE),
     &wt(MWALK),eigv,eest,wdsumo,wgdsumo,fprod,nwalk
      common /header/ title,date
      common /age/ iage(MWALK),ioldest,ioldestmx
      common /gradhess/ grad(MPARM),grad_var(MPARM),hess(MPARM,MPARM),hess_var(MPARM,MPARM),gerr(MPARM),
     &add_diag(3),energy(3),energy_sigma(3),energy_err(3),force(3),force_err(3),
     &eig_min,eig_max,p_var,tol_energy,nopt_iter,nblk_max
      common /pairden/ xx0probut(0:NAX,-NAX:NAX,-NAX:NAX),xx0probuu(0:NAX,-NAX:NAX,-NAX:NAX),
     &xx0probud(0:NAX,-NAX:NAX,-NAX:NAX),xx0probdt(0:NAX,-NAX:NAX,-NAX:NAX),
     &xx0probdu(0:NAX,-NAX:NAX,-NAX:NAX),xx0probdd(0:NAX,-NAX:NAX,-NAX:NAX),
     &den2d_t(-NAX:NAX,-NAX:NAX),den2d_d(-NAX:NAX,-NAX:NAX),den2d_u(-NAX:NAX,-NAX:NAX),
     &delxi,xmax,xfix(3),ifixe
      common /fourier/ fourierrk_u(0:NAX,0:NAK1),fourierrk_d(0:NAX,0:NAK1)
     &,fourierrk_t(0:NAX,0:NAK1),fourierkk_u(-NAK2:NAK2,-NAK2:NAK2),fourierkk_d(-NAK2:NAK2,-NAK2:NAK2)
     &,fourierkk_t(-NAK2:NAK2,-NAK2:NAK2),delk1,delk2,fmax1,fmax2,ifourier
      common /dot/ w0,we,bext,emag,emaglz,emagsz,glande,p1,p2,p3,p4,rring
      common /compferm/ emagv,nv,idot

      character*80 title,fmt
      character*24 date
      character*16 mode

c statement functions for error calculation
      rn_eff(w,w2)=w**2/w2

      error(x,x2,w,w2)=dsqrt(max((x2/w-(x/w)**2)/(rn_eff(w,w2)-1),0.d0))
      errorn(x,x2,rn)=dsqrt(max((x2/rn-(x/rn)**2)/(rn-1),0.d0))
      errori(x,x2,w,w2,rn)=dsqrt(max((x2/rn-(x/rn)**2)/(rn_eff(w,w2)-1),
     &0.d0))
      errc(x,x2)=error(x,x2,wcum,wcm2)
      errf(x,x2)=error(x,x2,wfcum,wfcm2)
      errg(x,x2,i)=error(x,x2,wgcum(i),wgcm2(i))
      errc1(x,x2)=error(x,x2,wcum1,wcm21)
      errf1(x,x2)=error(x,x2,wfcum1,wfcm21)
      errg1(x,x2,i)=error(x,x2,wgcum1(i),wgcm21(i))
      errw(x,x2)=errorn(x,x2,dfloat(iblk))/nstep
      errw1(x,x2)=errorn(x,x2,passes)
      erric(x,x2)=errori(x,x2,wcum,wcm2,dfloat(iblk))
      erric1(x,x2)=errori(x,x2,wcum1,wcm21,passes)
      errig(x,x2)=errori(x,x2,wgcum(1),wgcm2(1),dfloat(iblk))

      passes=dfloat(iblk*nstep)
      eval=nconf*passes
c Either the next 3 lines or the 3 lines following them could be used.
c They should give nearly (but not exactly) the same result.
c Strictly the 1st 3 are for step-by-step quantities and the last 3 for blk-by-blk
c     eval_eff=nconf*rn_eff(wcum1,wcm21)
c     evalf_eff=nconf*rn_eff(wfcum1,wfcm21)
c     evalg_eff=nconf*rn_eff(wgcum1(1),wgcm21(1))
      eval_eff=nconf*nstep*rn_eff(wcum,wcm2)
      evalf_eff=nconf*nstep*rn_eff(wfcum,wfcm2)
      evalg_eff=nconf*nstep*rn_eff(wgcum(1),wgcm2(1))
      rtpass1=dsqrt(passes-1)
      rteval=dsqrt(eval)
      rteval_eff1=dsqrt(eval_eff-1)
      rtevalf_eff1=dsqrt(evalf_eff-1)
      rtevalg_eff1=dsqrt(evalg_eff-1)

      write(6,'(/,''Final write:'')')

c Write out radial charge density for atoms
      if(print_radial_probability .and. iperiodic.eq.0 .and. ncent.eq.1 .and. ipr.ge.-1) then
        if(ndim.eq.3) write(6,'(/,'' r  4*pi*r^2*rho 4*pi*r^2*rhoup 4*pi*r^2*rhodn'')')
        if(ndim.eq.2) write(6,'(/,'' r  2*pi*r*rho 2*pi*r*rhoup 2*pi*r*rhodn'')')
        delr=one/delri
        term=one/(wgcum(1)*delr)
        do 5 i=1,NRAD
    5     write(6,'(f12.8,3f10.6)') delr*(i-half),rprob(i)*term,
     &    rprobup(i)*term,rprobdn(i)*term
      endif

      if(idmc.ge.0) then
        write(6,'(/,''ages of walkers are:'')')
        write(6,'(10i4)') (iage(i),i=1,nwalk)
        do 10 i=1,nwalk
          if(iage(i).gt.50) then
            write(6,'(i4,i6,f10.4,99f8.4)') i,iage(i),eoldw(i,1),
     &      ((xoldw(k,j,i,1),k=1,ndim),j=1,nelec)
            write(6,'(99f8.4)') ((voldw(k,j,i,1),k=1,ndim),j=1,nelec)
          endif
   10   continue

        write(6,'(''age of oldest walker (this generation, any gen)='',
     &   3i9)') ioldest,ioldestmx
      endif

      write(6,'(''average of the squares of the accepted step-size='',
     & f10.5)') dr2ac/try_int

      write(6,'(''taueff'',20f7.4)') (taucum(ifr)/wgcum(ifr),
     & ifr=1,nforce)

      accav=acc/try_int
      accavn=acc_int/try_int

      wave=wcum/passes
      wfave=wfcum/passes
      eave=ecum/wcum
      efave=efcum/wfcum
      ei1ave=wfcum/wdcum
      ei2ave=wgcum(1)/wgdcum
      ei3ave=ei3cum/passes

      r2ave=r2cum/(wgcum(1)*nelec)
      riave=ricum/(wgcum(1)*nelec)
      e1ave=etrial-dlog(ei1ave)/(taucum(1)/wgcum(1))
      e2ave=etrial-dlog(ei2ave)/(taucum(1)/wgcum(1))
      e3ave=etrial-dlog(ei3ave)/(taucum(1)/wgcum(1))

      if(iblk.eq.1) then
        werr=0
        wferr=0
        werr1=0
        wferr1=0
        eerr=0
        eferr=0
        eerr1=0
        eferr1=0
        ei1err=0
        ei2err=0
        ei3err=0
        r2err=0
        rierr=0
       else
        werr=errw(wcum,wcm2)
        wferr=errw(wfcum,wfcm2)
        werr1=errw1(wcum1,wcm21)
        wferr1=errw1(wfcum1,wfcm21)
        eerr=errc(ecum,ecm2)
        eferr=errf(efcum,efcm2)
        eerr1=errc1(ecum1,ecm21)
        eferr1=errf1(efcum1,efcm21)
        ei1err=erric(ei1cum,ei1cm2)
        ei2err=errig(ei2cum,ei2cm2)
        ei3err=erric1(ei3cum,ei3cm2)
        r2err=errg(r2cum,r2cm2,1)/nelec
        rierr=errg(ricum,ricm2,1)/nelec
      endif

      e1err=dlog((ei1ave+ei1err)/(ei1ave-ei1err))/(2*taucum(1)/wgcum(1))
      e2err=dlog((ei2ave+ei2err)/(ei2ave-ei2err))/(2*taucum(1)/wgcum(1))
      e3err=dlog((ei3ave+ei3err)/(ei3ave-ei3err))/(2*taucum(1)/wgcum(1))

c     write(6,'(''dmc_mov1 '',2a10)') title
      write(fmt,'(''(/,a16,2x,a'',i3,'')'')') len_trim(title)
      write(6,fmt) mode,title

      write(6,'(''No/frac. of node crossings,acceptance='',i9,3f10.6)')
     &nodecr,dfloat(nodecr)/try_int,accav,accavn
      if(idmc.lt.0.and.accav.lt.0.3) write(6,'(''Warning: Low acceptance, reduce time-step tau'')')
      if(idmc.ge.0.and.accav.lt.0.7) write(6,'(''Warning: Low acceptance, reduce time-step tau'')')
      if(idmc.ge.0) then
        write(6,'(''Actual, expected # of branches for 0, inf corr time='',
     &  i6,2f9.0)') nbrnch
     &  ,nconf*passes*(dlog(one+eerr1*rteval*taucum(1)/wgcum(1))/dlog(two))**2
     &  ,nconf*passes*(dlog(one+eerr1*rteval*taucum(1)/wgcum(1))/dlog(two))
        write(6,'(''No. of walkers at end of run='',i5)') nwalk

        write(6,'(''nwalk_eff/nwalk         ='',2f6.3)')
     &  rn_eff(wcum1,wcm21)/passes,rn_eff(wcum,wcm2)/iblk
        write(6,'(''nwalk_eff/nwalk with f  ='',2f6.3)')
     &  rn_eff(wfcum1,wfcm21)/passes,rn_eff(wfcum,wfcm2)/iblk
        write(6,'(''nwalk_eff/nwalk with fs ='',2f6.3)')
     &  rn_eff(wgcum1(1),wgcm21(1))/passes,rn_eff(wgcum(1),wgcm2(1))/iblk
      endif

      write(6,'(''nconf*passes     passes   nconf nstep  nblk nblkeq  tau    taueff'',/,
     & 2f12.0,2i6,i7,i5,2f9.5)') eval,passes,nconf,nstep,iblk,nblkeq,tau,taucum(1)/wgcum(1)
      write(6,'(''physical variable         average     rms error   sigma*T_cor  sigma   T_cor'')')
      if(idmc.ge.0) then
        write(6,'(''weights ='',t22,f14.7,'' +-'',f11.7,2f9.5,f8.2)')
     &  wave,werr,werr*rtpass1,werr1*rtpass1,(werr/werr1)**2
        write(6,'(''wts with f ='',t22,f14.7,'' +-'',f11.7,2f9.5,f8.2)')
     &  wfave,wferr,wferr*rtpass1,wferr1*rtpass1,(wferr/wferr1)**2
        do 20 ifr=1,nforce
          wgave=wgcum(ifr)/passes
          wgerr=errw(wgcum(ifr),wgcm2(ifr))
          wgerr1=errw1(wgcum1(ifr),wgcm21(ifr))
          write(6,'(''wts with fs ='',t22,f14.7,'' +-'',f11.7,2f9.5,f8.2)')
     &    wgave,wgerr,wgerr*rtpass1,wgerr1*rtpass1,(wgerr/wgerr1)**2
  20    continue
c Mixed energy estimators
        write(6,'(''total energy (   0) ='',t22,f14.7,'' +-'',f11.7,
     &  2f9.5,f8.2)') eave,eerr,eerr*rteval_eff1,eerr1*rteval_eff1,
     &  (eerr/eerr1)**2
        write(6,'(''total energy (   1) ='',t22,f14.7,'' +-'',f11.7,
     &  2f9.5,f8.2)') efave,eferr,eferr*rtevalf_eff1,eferr1*rtevalf_eff1,
     &  (eferr/eferr1)**2
      endif
      do 30 ifr=1,nforce
        egave=egcum(ifr)/wgcum(ifr)
        egerr=errg(egcum(ifr),egcm2(ifr),ifr)
        egerr1=errg1(egcum1(ifr),egcm21(ifr),ifr)
c save energy, energy_sigma and energy_err for optimization
        energy(ifr)=egave
        energy_sigma(ifr)=egerr1*rtevalg_eff1
        energy_err(ifr)=egerr
        write(6,'(''total energy ('',i4,'') ='',t22,f14.7,'' +-'',
     &  f11.7,2f9.5,f8.2)') nfprod,egave,egerr,egerr*rtevalg_eff1,
     &  egerr1*rtevalg_eff1,(egerr/egerr1)**2
  30  continue
c Growth energy estimators
      if(idmc.ge.0) then
        write(6,'(''total energy (   0) ='',t22,f14.7,'' +-'',f11.7,
     &  f9.5)') e1ave,e1err,e1err*rteval_eff1
        write(6,'(''total energy ('',i4,'') ='',t22,f14.7,'' +-'',f11.7,
     &  f9.5)') nfprod-1,e2ave,e2err,e2err*rtevalg_eff1
        write(6,'(''total energy ='',t22,f14.7,'' +-'',f11.7,
     &  f9.5)') e3ave,e3err,e3err*rteval_eff1
      endif
      do 40 ifr=1,nforce
        peave=pecum(ifr)/wgcum(ifr)
        peiave=peicum(ifr)/wgcum(ifr)
        tpbave=tpbcum(ifr)/wgcum(ifr)
        tjfave=tjfcum(ifr)/wgcum(ifr)

        peerr=errg(pecum(ifr),pecm2(ifr),ifr)
        peierr=errg(peicum(ifr),peicm2(ifr),ifr)
        tpberr=errg(tpbcum(ifr),tpbcm2(ifr),ifr)
        tjferr=errg(tjfcum(ifr),tjfcm2(ifr),ifr)

c separate "magnetic energy" for quantum dots:
        if(ndim.eq.2) then
          temp=0.25d0*bext*bext/(we*we)
          tmave=(peave-peiave-emag)*temp
          tmerr=(peerr+peierr)*temp
          peave=peave-tmave-emag
c         peerr=peerr+tmerr     ! is this correct?
          peerr=peerr*(1-temp)+peierr*temp
        endif

        write(6,'(''potential energy ='',t22,f14.7,'' +-''
     &  ,f11.7,f9.5)') peave,peerr,peerr*rtevalg_eff1
        write(6,'(''interaction energy ='',t22,f14.7,'' +-''
     &  ,f11.7,f9.5)') peiave,peierr,peierr*rtevalg_eff1
        write(6,'(''jf kinetic energy ='',t22,f14.7,'' +-''
     &  ,f11.7,f9.5)') tjfave,tjferr,tjferr*rtevalg_eff1
        write(6,'(''pb kinetic energy ='',t22,f14.7,'' +-''
     &  ,f11.7,f9.5)') tpbave,tpberr,tpberr*rtevalg_eff1

        if(ndim.eq.2) then
          write(6,'(''radial mag. energy ='',t22,f14.7,'' +-'',
     &    f11.7,f9.5)') tmave,tmerr,tmerr*rtevalg_eff1
          write(6,'(''orbital mag. energy ='',t22,f14.7)') emaglz+emagv
          write(6,'(''Zeeman energy ='',t22,f14.7)') emagsz
        endif  

  40  continue
      do 50 ifr=2,nforce
        fgave=egcum(ifr)/wgcum(ifr)-egcum(1)/wgcum(1)
        fgerr=errg(fgcum(ifr),fgcm2(ifr),1)
c       fgave=fgave/deltot(ifr)
c       fgerr=fgerr/abs(deltot(ifr))
c save energy difference and error in energy difference for optimization
        force(ifr)=fgave
        force_err(ifr)=fgerr
        write(6,'(''total energy diff'',i2,t22,f14.7
     &  ,'' +-'',f11.7,f9.5)') ifr,fgave,fgerr,fgerr*rtevalg_eff1
  50  continue

      if(iperiodic.eq.0 .and. ncent.eq.1) then
        write(6,'(''<r2>_av ='',t22,f14.7,'' +-''
     &  ,f11.7,f9.5)') r2ave,r2err,r2err*rtevalg_eff1
        write(6,'(''<ri>_av ='',t22,f14.7,'' +-''
     &  ,f11.7,f9.5)') riave,rierr,rierr*rtevalg_eff1
      endif

      if(ipr.gt.-2)
     &  write(11,'(3i5,f11.5,f7.4,f10.7,
     &  '' nstep,nblk,nconf,etrial,tau,taueff'')')
     &  nstep,iblk,nconf,etrial,tau,taucum(1)/wgcum(1)

      if(ifixe.ne.0 .or. ifourier.ne.0) call den2dwrt(wgcum(1))

      return
      end
