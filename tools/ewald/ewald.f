      subroutine set_ewald
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'force.h'
      include 'ewald.h'
      include 'pseudo.h'

      parameter (eps=1.d-12)

      common /dim/ ndim
      common /contrl_per/ iperiodic,ibasis
      common /constant/ twopi
      common /const/ pi,hb,etrial,delta,deltai,fbias,nelec,imetro,ipr
      common /atom/ znuc(MCTYPE),cent(3,MCENT),pecent
     &,iwctype(MCENT),nctype,ncent
c     common /pseudo_fahy/ potl(MPS_GRID,MCTYPE),ptnlc(MPS_GRID,MCTYPE,MPS_L)
c    &,dradl(MCTYPE),drad(MCTYPE),rcmax(MCTYPE),npotl(MCTYPE)
c    &,nlrad(MCTYPE)
      common /pseudo_tm/ rmax_coul(MCTYPE),rmax_nloc(MCTYPE),arg_ps(MCTYPE),r0_ps(MCTYPE)
     &,vpseudo(MPS_GRID,MCTYPE,MPS_L),d2pot(MPS_GRID,MCTYPE,MPS_L),igrid_ps(MCTYPE),nr_ps(MCTYPE)
      common /pseudo/ vps(MELEC,MCENT,MPS_L),vpso(MELEC,MCENT,MPS_L,MFORCE)
     &,npotd(MCTYPE),lpotp1(MCTYPE),nloc
      common /periodic/ rlatt(3,3),glatt(3,3),rlatt_sim(3,3),glatt_sim(3,3)
     &,rlatt_inv(3,3),rlatt_sim_inv(3,3),glatt_inv(3,3)
     &,cutr,cutr_sim,cutg,cutg_sim,cutg_big,cutg_sim_big
     &,igvec(3,NGVEC_BIGX),gvec(3,NGVEC_BIGX),gnorm(NGNORM_BIGX),igmult(NGNORM_BIGX)
     &,igvec_sim(3,NGVEC_SIM_BIGX),gvec_sim(3,NGVEC_SIM_BIGX),gnorm_sim(NGNORM_SIM_BIGX),igmult_sim(NGNORM_SIM_BIGX)
     &,rkvec_shift(3),kvec(3,MKPTS),rkvec(3,MKPTS),rknorm(MKPTS)
     &,k_inv(MKPTS),nband(MKPTS),ireal_imag(MORB)
     &,znuc_sum,znuc2_sum,vcell,vcell_sim
     &,ngnorm,ngvec,ngnorm_sim,ngvec_sim,ngnorm_orb,ngvec_orb,nkvec
     &,ngnorm_big,ngvec_big,ngnorm_sim_big,ngvec_sim_big
     &,ng1d(3),ng1d_sim(3),npoly,ncoef,np,isrange
      common /ewald/ b_coul(NCOEFX),y_coul(NGNORMX)
     &,b_coul_sim(NCOEFX),y_coul_sim(NGNORM_SIMX)
     &,b_psp(NCOEFX,MCTYPE),y_psp(NGNORMX,MCTYPE)
     &,b_jas(NCOEFX),y_jas(NGNORM_SIMX)
     &,cos_n_sum(NGVECX),sin_n_sum(NGVECX),cos_e_sum(NGVECX),sin_e_sum(NGVECX)
     &,cos_e_sum_sim(NGVEC_SIMX),sin_e_sum_sim(NGVEC_SIMX)
     &,cos_p_sum(NGVECX),sin_p_sum(NGVECX)
c Note vbare_coul is used both for prim. and simul. cells, so dimension it for simul. cell
      common /test/ f,vbare_coul(NGNORM_SIM_BIGX),vbare_jas(NGNORM_SIM_BIGX)
     &,vbare_psp(NGNORM_BIGX)
      common /ewald_basis/ vps_basis_fourier(NGNORM_BIGX)

      common /tempor/ dist_nn

      dimension r(MPS_GRID),vps_short(MPS_GRID),work(MPS_GRID)
      dimension rdist(3),gdist(3),rdist_sim(3),gdist_sim(3),rkvec_shift_tmp(3)

c Temporary
      dimension r_tmp(3)

      pi=4.d0*datan(1.d0)
      twopi=2*pi

      ncoef=npoly+1

c Check that the lattice vectors are the smallest possible ones and return the smallest
c which is used to set the range of the real-space Ewald sums so that only one image
c of a nucleus or an electron is present within cutr and cutr_sim respectively.
      call check_lattice(rlatt,cutr,0)
      call check_lattice(rlatt_sim,cutr_sim,1)
      write(6,'(''cutr,cutr_sim ='',9f9.5)') cutr,cutr_sim

c Calculate inverse transformations (from lattice coordinates to real coordinates)
c and cell volumes
      do 5 i=1,ndim
        do 5 k=1,ndim
          rlatt_inv(k,i)=rlatt(k,i)
    5     rlatt_sim_inv(k,i)=rlatt_sim(k,i)
      call matinv(rlatt_inv,3,det)
      call matinv(rlatt_sim_inv,3,det_sim)


c Primitive cell volume and reciprocal lattice
c     det=rlatt(1,1)*rlatt(2,2)*rlatt(3,3)
c    &   +rlatt(2,1)*rlatt(3,2)*rlatt(1,3)
c    &   +rlatt(3,1)*rlatt(1,2)*rlatt(2,3)
c    &   -rlatt(3,1)*rlatt(2,2)*rlatt(1,3)
c    &   -rlatt(1,1)*rlatt(3,2)*rlatt(2,3)
c    &   -rlatt(2,1)*rlatt(1,2)*rlatt(3,3)
      det1=twopi/det
      glatt(1,1)=det1*(rlatt(2,2)*rlatt(3,3)-rlatt(2,3)*rlatt(3,2))
      glatt(2,1)=det1*(rlatt(3,2)*rlatt(1,3)-rlatt(3,3)*rlatt(1,2))
      glatt(3,1)=det1*(rlatt(1,2)*rlatt(2,3)-rlatt(1,3)*rlatt(2,2))
      glatt(1,2)=det1*(rlatt(2,3)*rlatt(3,1)-rlatt(2,1)*rlatt(3,3))
      glatt(2,2)=det1*(rlatt(3,3)*rlatt(1,1)-rlatt(3,1)*rlatt(1,3))
      glatt(3,2)=det1*(rlatt(1,3)*rlatt(2,1)-rlatt(1,1)*rlatt(2,3))
      glatt(1,3)=det1*(rlatt(2,1)*rlatt(3,2)-rlatt(2,2)*rlatt(3,1))
      glatt(2,3)=det1*(rlatt(3,1)*rlatt(1,2)-rlatt(3,2)*rlatt(1,1))
      glatt(3,3)=det1*(rlatt(1,1)*rlatt(2,2)-rlatt(1,2)*rlatt(2,1))

      write(6,'(/,''Reciprocal lattice basis vectors'',3(/,3f10.6))')
     & ((glatt(k,j),k=1,ndim),j=1,ndim)

      vcell=dabs(det)
      write(6,'(/,''Cell volume'',f15.8)') det

c Simulation cell volume and reciprocal lattice
c     det=rlatt_sim(1,1)*rlatt_sim(2,2)*rlatt_sim(3,3)
c    &   +rlatt_sim(2,1)*rlatt_sim(3,2)*rlatt_sim(1,3)
c    &   +rlatt_sim(3,1)*rlatt_sim(1,2)*rlatt_sim(2,3)
c    &   -rlatt_sim(3,1)*rlatt_sim(2,2)*rlatt_sim(1,3)
c    &   -rlatt_sim(1,1)*rlatt_sim(3,2)*rlatt_sim(2,3)
c    &   -rlatt_sim(2,1)*rlatt_sim(1,2)*rlatt_sim(3,3)
      det1=twopi/det_sim
      glatt_sim(1,1)=det1*(rlatt_sim(2,2)*rlatt_sim(3,3)-rlatt_sim(2,3)*rlatt_sim(3,2))
      glatt_sim(2,1)=det1*(rlatt_sim(3,2)*rlatt_sim(1,3)-rlatt_sim(3,3)*rlatt_sim(1,2))
      glatt_sim(3,1)=det1*(rlatt_sim(1,2)*rlatt_sim(2,3)-rlatt_sim(1,3)*rlatt_sim(2,2))
      glatt_sim(1,2)=det1*(rlatt_sim(2,3)*rlatt_sim(3,1)-rlatt_sim(2,1)*rlatt_sim(3,3))
      glatt_sim(2,2)=det1*(rlatt_sim(3,3)*rlatt_sim(1,1)-rlatt_sim(3,1)*rlatt_sim(1,3))
      glatt_sim(3,2)=det1*(rlatt_sim(1,3)*rlatt_sim(2,1)-rlatt_sim(1,1)*rlatt_sim(2,3))
      glatt_sim(1,3)=det1*(rlatt_sim(2,1)*rlatt_sim(3,2)-rlatt_sim(2,2)*rlatt_sim(3,1))
      glatt_sim(2,3)=det1*(rlatt_sim(3,1)*rlatt_sim(1,2)-rlatt_sim(3,2)*rlatt_sim(1,1))
      glatt_sim(3,3)=det1*(rlatt_sim(1,1)*rlatt_sim(2,2)-rlatt_sim(1,2)*rlatt_sim(2,1))

      write(6,'(/,''Simulation cell reciprocal lattice basis vectors'',3(/,3f10.6))')
     & ((glatt_sim(k,j),k=1,ndim),j=1,ndim)

      vcell_sim=dabs(det_sim)
      write(6,'(/,''Simulation cell volume'',f15.8)') det_sim
      write(6,'(/,''Simulation cell volume is'',i3,'' times primitive cell volume'')')
     &nint(vcell_sim/vcell)
      if((vcell_sim/vcell)-nint(vcell_sim/vcell).gt.1.d-9) then
        write(6,'(''Warning: vcell_sim/vcell='',f9.5, '' not an integer'')') vcell_sim/vcell
        stop 'Simulation cell volume is not a multiple of the primitive cell volume'
      endif
      if(nint(vcell_sim/vcell).gt.MKPTS) then
        write(6,'(''Warning: vcell_sim/vcell > MKPTS'',2i4)') nint(vcell_sim/vcell),MKPTS
        stop 'vcell_sim/vcell > MKPTS'
      endif

c Calculate inverse transformation for reciprocal lattice (from lattice coordinates to real coordinates)
c Needed to transform k-vectors
      do 7 i=1,ndim
        do 7 k=1,ndim
    7     glatt_inv(k,i)=glatt(k,i)
      call matinv(glatt_inv,3,det)


c real-space distances
c primitive cell
      call short_distance(rlatt,vcell,dist_min,rdist)
c     cutr=0.5d0*dist_min
c     cutr=min(rmax_coul(ict),cutr)
      write(6,'(/,''Shortest distance to cell boundary'',f14.8)') dist_min/2

c simulation cell
      call short_distance(rlatt_sim,vcell_sim,dist_min,rdist_sim)
c     cutr_sim=0.5d0*dist_min
      write(6,'(/,''Shortest distance to simu cell boundary'',f14.8)') dist_min/2

c reciprocal-space distances
c primitive cell
      vgcell=twopi**3/vcell
      call short_distance(glatt,vgcell,gdistmin,gdist)
      write(6,'(/,''Shortest distance to recip. cell boundary'',f14.8)') gdistmin

c simulation cell
      vgcell_sim=twopi**3/vcell_sim
      call short_distance(glatt_sim,vgcell_sim,gdistmin_sim,gdist_sim)
      write(6,'(/,''Shortest distance to sim. recip. cell boundary'',f14.8)') gdistmin_sim


c generate shells of primitive cell g-vectors
      call shells(cutg_big,glatt,gdist,igvec,gvec,gnorm,igmult,ngvec_big,
     &ngnorm_big,ng1d,0)

      ngnorm=ngnorm_big
      ngvec=0
      do 10 k=1,ngnorm_big
        if(gnorm(k).gt.cutg+eps) then
          ngnorm=k-1
          goto 20
        endif
        ngvec=ngvec+igmult(k)
   10 continue

   20 write(6,'(/,''Shells within cutg_big,cutg'',2i8)') ngnorm_big,ngnorm
      write(6,'(/,''Vects. within cutg_big,cutg'',2i8)') ngvec_big,ngvec
      write(6,'(/,''ng1d for primitive cell'',3i4)') (ng1d(k),k=1,ndim)
      if(ngvec.gt.NGVECX) then
        write(6,'(''ngvec,NGVECX='',2i8)') ngvec,NGVECX
        stop 'ngvec>NGVECX in set_ewald'
      endif
      if(ngnorm.gt.NGNORMX) then
        write(6,'(''ngnorm,NGNORMX='',2i8)') ngnorm,NGNORMX
        stop 'ngnorm>NGNORMX in set_ewald'
      endif
      do 30 k=1,ndim
        if(ng1d(k).gt.NG1DX) then
          write(6,'(''k,ng1d(k),NG1DX='',i1,2i8)') k,ng1d(k),NG1DX
          stop 'ng1d(k)>NG1DX in set_ewald'
        endif
   30 continue

      open(1,file='gvectors_qmc')
      write(1,'(i5,'' ngvec (half of them only)'')') ngvec
      write(1,'(3i5,3f8.4)') ((igvec(k,i),k=1,ndim),(gvec(k,i),k=1,ndim),i=1,ngvec)
      close(1)

c generate shells of simulation cell g-vectors
      call shells(cutg_sim_big,glatt_sim,gdist_sim,igvec_sim,gvec_sim,gnorm_sim,igmult_sim,ngvec_sim_big,
     & ngnorm_sim_big,ng1d_sim,1)

      ngnorm_sim=ngnorm_sim_big
      ngvec_sim=0
      do 40 k=1,ngnorm_sim_big
        if(gnorm_sim(k).gt.cutg_sim+eps) then
          ngnorm_sim=k-1
          goto 50
        endif
        ngvec_sim=ngvec_sim+igmult_sim(k)
   40 continue

   50 write(6,'(/,''Shells within cutg_sim_big,cutg_sim'',2i8)') ngnorm_sim_big,ngnorm_sim
      write(6,'(/,''Vects. within cutg_sim_big,cutg_sim'',2i8)') ngvec_sim_big,ngvec_sim
      write(6,'(/,''ng1d for simulation cell'',3i4)') (ng1d_sim(k),k=1,ndim)
      if(ngvec_sim.gt.NGVEC_SIMX) stop 'ngvec_sim>NGVEC_SIMX in set_ewald'
      if(ngnorm_sim.gt.NGNORM_SIMX) stop 'ngnorm_sim>NGNORM_SIMX in set_ewald'
      do 60 k=1,ndim
   60   if(ng1d_sim(k).gt.NG1DX) stop 'ng1d_sim(k)>NG1DX in shells'

c Convert k-vector shift from simulation-cell recip. lattice vector units to cartesian coordinates
      do 62 k=1,ndim
   62   rkvec_shift_tmp(k)=rkvec_shift(k)
      do 65 k=1,ndim
        rkvec_shift(k)=0
        do 65 i=1,ndim
   65     rkvec_shift(k)=rkvec_shift(k)+rkvec_shift_tmp(i)*glatt_sim(k,i)
      write(6,'(/,''rkvec_shift in sim-cell recip. lat. vec. units'',9f9.4)') (rkvec_shift_tmp(k),k=1,ndim)
      write(6,'(''rkvec_shift in cartesian coodinates'',9f9.4)') (rkvec_shift(k),k=1,ndim)

c Generate k-vectors, i.e. simulation-cell recip. lattice vectors shifted by rkvec_shift that are
c not related by a primitive-cell recip. lattice vector.
      call k_vectors


c Coulomb interactions in primitive and simulation cells
c nconstraint=2 imposes that linear part of vsrange 1/r is zero.
      lowest_pow=-1
      b0=1.d0
c     nconstraint=2
c     nconstraint=1
      nconstraint=5
c     nconstraint=7
c     isrange=0
      isrange=4

c n-n, e-n interactions (primitive cell)
c put in uniform background by setting k=0 term to zero
      vbare_coul(1)=0.d0
      do 70 k=2,ngnorm_big
c Fourier transfom of 1/r
   70   vbare_coul(k)=2*twopi/(vcell*gnorm(k)**2)

      call separate(vbare_coul,b0,lowest_pow,ngnorm_big,igmult,gnorm,ngnorm
     &,cutr,vcell,ncoef,np,b_coul,y_coul,chisq,nconstraint,isrange)

      if(chisq.gt.0) then
        rms=dsqrt(chisq)
        write(6,'(''Rms error of 1/r separation (prim cell)'',d12.5)') rms
        if(rms.gt.1.d-3) write(6,'(''Warning: Rms error of 1/r separation (prim cell)'',d12.5, '' Increase cutg'')') rms
       else
        write(6,'(''Warning: Rms error missing, chisq negative in 1/r primitive separate'',d12.4)') chisq
        if(chisq.lt.-1.d-15) stop 'chisq<0 in separate'
      endif

      if(ipr.ge.0) write(6,'(/,''Separation of Coulomb interaction (prim cell)'')')
      if(ipr.eq.1) write(6,'(''vbare_coul = '',20d12.4)') (vbare_coul(k),k=1,ngnorm)
      if(ipr.ge.2) write(6,'(''vbare_coul = '',20d12.4)') (vbare_coul(k),k=ngnorm+1,ngnorm_big)
      if(ipr.ge.0) write(6,'(''y_coul = '',20d12.4)') (y_coul(k),k=1,ngnorm)
      if(ipr.ge.0) write(6,'(''b_coul = '',20d12.4)') (b_coul(k),k=1,ncoef)

c debug n-n and e-n interaction (primitive cell)
c check on 2*npts points along two different lines.
      if(ipr.ge.0) then
        write(6,'(''      r       "true"      ewald       test       ewald-true   test-true       1/r     d_true   d_test    vsrange
     &    vlrange'')')
        lowest_pow=-1
        npts=101
        dx=cutr/(npts-1)

        rms=0
        do 75 i=1,npts
          r_tmp(1)=(i-1)*dx+1.d-3
          r_tmp(2)=0
          r_tmp(3)=0
          rr=sqrt(r_tmp(1)**2+r_tmp(2)**2+r_tmp(3)**2)
          vs=vsrange4(rr,cutr,lowest_pow,ncoef,np,b_coul,junk,junk)
          vl=vlrange_old(r_tmp,gvec,ngnorm,igmult,y_coul)
          test=vs+vl
c         true=vlrange_old(r_tmp,gvec,ngnorm_big,igmult,vbare_coul)
          true=ewald_pot(r_tmp,rr,gvec,gnorm,ngnorm_big,igmult,vbare_coul,cutr,vcell)
          ewa=ewald_pot(r_tmp,rr,gvec,gnorm,ngnorm,igmult,vbare_coul,cutr,vcell)
          rms=rms+(true-test)**2
          if(i.eq.1) then
            write(6,'(''1/r'',f8.4,3f12.6,2f12.8,30x,2f12.6)') rr,true,ewa,test,ewa-true,test-true,vs,vl
           else
            write(6,'(''1/r'',f8.4,3f12.6,2f12.8,f12.6,2f9.3,2f12.6)') rr,true,ewa,test,ewa-true,test-true
     &      ,1/rr,(true-true_s)/dx,(test-test_s)/dx,vs,vl
          endif
          true_s=true
   75   test_s=test

c Check along second line
        dx=cutr/((npts-1)*sqrt(1.d0+4.d0+9.d0))
        dr=cutr/(npts-1)

        do 77 i=1,npts
          r_tmp(1)=(i-1)*dx  +1.d-3
          r_tmp(2)=(i-1)*dx*2+1.d-3
          r_tmp(3)=(i-1)*dx*3+1.d-3
          rr=sqrt(r_tmp(1)**2+r_tmp(2)**2+r_tmp(3)**2)
          vs=vsrange4(rr,cutr,lowest_pow,ncoef,np,b_coul,junk,junk)
          vl=vlrange_old(r_tmp,gvec,ngnorm,igmult,y_coul)
          test=vs+vl
c         true=vlrange_old(r_tmp,gvec,ngnorm_big,igmult,vbare_coul)
          true=ewald_pot(r_tmp,rr,gvec,gnorm,ngnorm_big,igmult,vbare_coul,cutr,vcell)
          ewa=ewald_pot(r_tmp,rr,gvec,gnorm,ngnorm,igmult,vbare_coul,cutr,vcell)
          rms=rms+(true-test)**2
          if(i.eq.1) then
            write(6,'(''1/r'',f8.4,3f12.6,2f12.8,30x,2f12.6)') rr,true,ewa,test,ewa-true,test-true,vs,vl
           else
            write(6,'(''1/r'',f8.4,3f12.6,2f12.8,f12.6,2f9.3,2f12.6)') rr,true,ewa,test,ewa-true,test-true
     &      ,1/rr,(true-true_s)/dx,(test-test_s)/dx,vs,vl
          endif
          true_s=true
   77   test_s=test
        rms=sqrt(rms/(2*npts))
        write(6,'(''Rms error of 1/r fit (prim cell)'',d12.4)') rms
        if(rms.gt.1.d-2) write(6,'(''Warning: rms error of 1/r fit (prim cell) too large'',d12.4)') rms
      endif


c e-e interactions (simulation cell) (we can reuse vbare_coul)
c put in uniform background by setting k=0 term to zero
      vbare_coul(1)=0.d0
      vbare_jas(1)=0.d0
      do 80 k=2,ngnorm_sim_big
c Fourier transfom of 1/r
        vbare_coul(k)=2*twopi/(vcell_sim*gnorm_sim(k)**2)
c Fourier transform of -1/r*(1-exp(-r/f)) for Jastrow
   80   vbare_jas(k)=-vbare_coul(k)/(1+(f*gnorm_sim(k))**2)

      call separate(vbare_coul,b0,lowest_pow,ngnorm_sim_big,igmult_sim,gnorm_sim,ngnorm_sim
     &,cutr_sim,vcell_sim,ncoef,np,b_coul_sim,y_coul_sim,chisq,nconstraint,isrange)

      if(chisq.gt.0) then
        rms=dsqrt(chisq)
        write(6,'(''Rms error of 1/r separation (simu cell)'',d12.5)') rms
        if(rms.gt.1.d-3) write(6,'(''Warning: Rms error of 1/r separation (simu cell)'',d12.5,'' Increase cutg_sim'')') rms
       else
        write(6,'(''Warning: Rms error missing, chisq negative in 1/r simulation separate'',d12.4)') chisq
        if(chisq.lt.-1.d-15) stop 'chisq<0 in separate'
      endif

      if(ipr.ge.0) write(6,'(/,''Separation of Coulomb interaction (simu cell)'')')
      if(ipr.eq.1) write(6,'(''vbare_coul = '',20d12.4)') (vbare_coul(k),k=1,ngnorm_sim)
      if(ipr.ge.2) write(6,'(''vbare_coul = '',20d12.4)') (vbare_coul(k),k=ngnorm_sim+1,ngnorm_sim_big)
      if(ipr.ge.0) write(6,'(''y_coul_sim = '',20d12.4)') (y_coul_sim(k),k=1,ngnorm_sim)
      if(ipr.ge.0) write(6,'(''b_coul_sim = '',20d12.4)') (b_coul_sim(k),k=1,ncoef)

c debug e-e interaction (simulation cell)
c check on 2*npts points along two different lines.
c Note vbare_coul is used both for primitive and simulation cells
      if(ipr.ge.0) then
        write(6,'(''      r       "true"      ewald       test       ewald-true   test-true       1/r     d_true   d_test    vsrange
     &    vlrange'')')
        lowest_pow=-1
        npts=101
        dx=cutr_sim/(npts-1)

        rms=0
        do 85 i=1,npts
          r_tmp(1)=(i-1)*dx+1.d-3
          r_tmp(2)=0
          r_tmp(3)=0
          rr=sqrt(r_tmp(1)**2+r_tmp(2)**2+r_tmp(3)**2)
          vs=vsrange4(rr,cutr_sim,lowest_pow,ncoef,np,b_coul_sim,junk,junk)
          vl=vlrange_old(r_tmp,gvec_sim,ngnorm_sim,igmult_sim,y_coul_sim)
          test=vs+vl
c         true=vlrange_old(r_tmp,gvec_sim,ngnorm_sim_big,igmult_sim,vbare_coul)
          true=ewald_pot(r_tmp,rr,gvec_sim,gnorm_sim,ngnorm_sim_big,igmult_sim,vbare_coul,cutr_sim,vcell_sim)
          ewa=ewald_pot(r_tmp,rr,gvec_sim,gnorm_sim,ngnorm_sim,igmult_sim,vbare_coul,cutr_sim,vcell_sim)
          rms=rms+(true-test)**2
          if(i.eq.1) then
            write(6,'(''1/r'',f8.4,3f12.6,2f12.8,30x,2f12.6)') rr,true,ewa,test,ewa-true,test-true,vs,vl
           else
            write(6,'(''1/r'',f8.4,3f12.6,2f12.8,f12.6,2f9.3,2f12.6)') rr,true,ewa,test,ewa-true,test-true
     &      ,1/rr,(true-true_s)/dx,(test-test_s)/dx,vs,vl
          endif
          true_s=true
   85   test_s=test

c Check along second line
        dx=cutr_sim/((npts-1)*sqrt(1.d0+4.d0+9.d0))
        dr=cutr_sim/(npts-1)

        do 87 i=1,npts
          r_tmp(1)=(i-1)*dx  +1.d-3
          r_tmp(2)=(i-1)*dx*2+1.d-3
          r_tmp(3)=(i-1)*dx*3+1.d-3
          rr=sqrt(r_tmp(1)**2+r_tmp(2)**2+r_tmp(3)**2)
          vs=vsrange4(rr,cutr_sim,lowest_pow,ncoef,np,b_coul_sim,junk,junk)
          vl=vlrange_old(r_tmp,gvec_sim,ngnorm_sim,igmult_sim,y_coul_sim)
          test=vs+vl
c         true=vlrange_old(r_tmp,gvec_sim,ngnorm_sim_big,igmult_sim,vbare_coul)
          true=ewald_pot(r_tmp,rr,gvec_sim,gnorm_sim,ngnorm_sim_big,igmult_sim,vbare_coul,cutr_sim,vcell_sim)
          ewa=ewald_pot(r_tmp,rr,gvec_sim,gnorm_sim,ngnorm_sim,igmult_sim,vbare_coul,cutr_sim,vcell_sim)
          rms=rms+(true-test)**2
          if(i.eq.1) then
            write(6,'(''1/r'',f8.4,3f12.6,2f12.8,30x,2f12.6)') rr,true,ewa,test,ewa-true,test-true,vs,vl
           else
            write(6,'(''1/r'',f8.4,3f12.6,2f12.8,f12.6,2f9.3,2f12.6)') rr,true,ewa,test,ewa-true,test-true
     &      ,1/rr,(true-true_s)/dx,(test-test_s)/dx,vs,vl
          endif
          true_s=true
   87   test_s=test
        rms=sqrt(rms/(2*npts))
        write(6,'(''Rms error of 1/r fit (prim cell)'',d12.4)') rms
        if(rms.gt.1.d-2) write(6,'(''Warning: rms error of 1/r fit (prim cell) too large'',d12.4)') rms
      endif


c e-e Jastrow
      if(iperiodic.eq.1) goto 88
      lowest_pow=0
      b0=0.5d0/f**2
      nconstraint=1
      isrange=0

      call separate(vbare_jas,b0,lowest_pow,ngnorm_sim_big,igmult_sim,gnorm_sim,ngnorm_sim
     &,cutr_sim,vcell_sim,ncoef,np,b_jas,y_jas,chisq,nconstraint,isrange)

      if(chisq.gt.0) then
        rms=dsqrt(chisq)
        write(6,'(''Rms error of Jastrow separation (simu cell)'',d12.5)') rms
        if(rms.gt.1.d-3) write(6,'(''Warning: Rms error of Jastrow separation (simu cell)'',d12.5)') rms
       else
        write(6,'(''Warning: Rms error missing, chisq negative in Jastrow separate'',d12.4)') chisq
        if(chisq.lt.-1.d-15) stop 'chisq<0 in separate'
      endif

      if(ipr.ge.0) write(6,'(/,''Separation of Jastrow (simu cell)'')')
      if(ipr.eq.1) write(6,'(''vbare_jas = '',20d12.4)') (vbare_jas(k),k=1,ngnorm_sim)
      if(ipr.ge.2) write(6,'(''vbare_jas = '',20d12.4)') (vbare_jas(k),k=ngnorm_sim+1,ngnorm_sim_big)
      if(ipr.ge.0) write(6,'(''y_jas = '',20d12.4)') (y_jas(k),k=1,ngnorm_sim)
      if(ipr.ge.0) write(6,'(''b_jas = '',20d12.4)') (b_jas(k),k=1,ncoef)

c debug e-e Jastrow
c Since Jastrow has singlularity at 0, cannot match there, so evaluate
c rms error only for latter 3/4 of interval
      if(ipr.ge.0) then
        write(6,'(''      r       "true"       test      test-true -1/r*(1-exp(-r/f) d_true d_test'')')
        lowest_pow=0
        npts=101
        dx=cutr_sim/(npts-1)
        rms=0
        do 86 i=1,npts
          r_tmp(1)=(i-1)*dx+1.d-3
          r_tmp(2)=0
          r_tmp(3)=0
          rr=sqrt(r_tmp(1)**2+r_tmp(2)**2+r_tmp(3)**2)
          test=vsrange(rr,cutr_sim,lowest_pow,ncoef,np,b_jas)
          test=test+vlrange_old(r_tmp,gvec_sim,ngnorm_sim,igmult_sim,y_jas)
          true=vlrange_old(r_tmp,gvec_sim,ngnorm_sim_big,igmult_sim,vbare_jas)
          if(4*i.ge.npts) rms=rms+(true-test)**2
          if(i.eq.1) then
            write(6,'(''jas'',f8.4,4f12.6,2f8.3)') rr,true,test,test-true
           else
            write(6,'(''jas'',f8.4,4f12.6,2f8.3)') rr,true,test,test-true
     &      ,-1/rr*(1-exp(-rr/f)),(true-true_s)/dx,(test-test_s)/dx
          endif
          true_s=true
   86   test_s=test
        rms=sqrt(4*rms/(3*npts))
        write(6,'(''Rms error of Jastrow fit (simu cell) on larger 3/4 interval'',d12.4)') rms
        if(rms.gt.1.d-2) write(6,'(''Warning: rms error of Jastrow fit too large'',d12.4)') rms
      endif

      if(nloc.eq.0) goto 197

c e-ion local pseudopotential
c Since local pseudopotential goes as -Z/r at large r, we do not need to do the
c separation for it.  Instead we use the separation for the Coulomb potential
c and just multiply the coefs. by -znuc and use the pseudopotential, rather
c than  1/r for one of the short-range functions.

      lowest_pow=0
      nconstraint=5
      isrange=4

   88 do 195 ict=1,nctype

      do 90 k=1,ngnorm
   90   y_psp(k,ict)=-znuc(ict)*y_coul(k)

      do 100 k=1,ncoef
  100   b_psp(k,ict)=-znuc(ict)*b_coul(k)

c The foll. is needed for checking only
c Warning it changes vpseudo and so should be removed.
c      do 110 ir=2,nr_ps(ict)
c        r(ir)=r0_ps(ict)*(arg_ps(ict)**(ir-1)-1.d0)
c        vps_short(ir)=vpseudo(ir,ict,lpotp1(ict))+znuc(ict)*(1-derfc(alpha*r(ir)))/r(ir)
cc       write(6,'(''r,vpseudo,z*derf/r,z/r'',9d12.4)') r(ir),vpseudo(ir,ict,lpotp1(ict))+znuc(ict)/r(ir),
cc    & -znuc(ict)*(1-derfc(alpha*r(ir)))/r(ir)+znuc(ict)/r(ir),vpseudo(ir,ict,lpotp1(ict))+znuc(ict)*(1-derfc(alpha*r(ir)))/r(ir)

c  110   vpseudo(ir,ict,lpotp1(ict))=vps_short(ir)

cc Derivative at origin 0 because of nature of psp, and at last pt 0 because we subtracted out asymp behaviour
c      dpot1=0
c      dpotn=0
c      call spline2(r,vpseudo(1,ict,lpotp1(ict)),nr_ps(ict),dpot1,dpotn,d2pot(1,ict,lpotp1(ict)),work)

      if(ipr.ge.0) write(6,'(''y_psp = '',20d12.4)') (y_psp(k,ict),k=1,ngnorm)
      if(ipr.ge.0) write(6,'(''b_psp = '',20d12.4)') (b_psp(k,ict),k=1,ncoef)

c If sim cell is not primitive cell, vbare_coul has been overwritten, so restore it
c n-n, e-n interactions (primitive cell)
c put in uniform background by setting k=0 term to zero
      if(vcell_sim.ne.vcell) then
        vbare_coul(1)=0.d0
        do 185 k=2,ngnorm_big
c Fourier transfom of 1/r
  185     vbare_coul(k)=2*twopi/(vcell*gnorm(k)**2)
      endif

      if(ipr.ge.0) then
        write(6,'(''      r       "true"      ewald       test       ewald-true   test-true       1/r     d_true   d_test    vsrange
     &    vlrange'')')
        npts=101
        dx=cutr/(npts-1)
        rms=0
        do 191 i=1,npts
          r_tmp(1)=(i-1)*dx+1.d-3
          r_tmp(2)=0
          r_tmp(3)=0
          rr=sqrt(r_tmp(1)**2+r_tmp(2)**2+r_tmp(3)**2)
          if(isrange.eq.4) vs=vsrange4(rr,cutr,lowest_pow,ncoef,np,b_psp(1,ict),ict,lpotp1(ict))
          vl=vlrange_old(r_tmp,gvec,ngnorm,igmult,y_psp(1,ict))
          test=vs+vl
c         true=vlrange_old(r_tmp,gvec,ngnorm_big,igmult,vbare_psp)
          true=ewald_pot_psp(r_tmp,rr,gvec,gnorm,ngnorm_big,igmult,vbare_coul,cutr,vcell,ict,lpotp1(ict),znuc(ict))
          ewa=ewald_pot_psp(r_tmp,rr,gvec,gnorm,ngnorm,igmult,vbare_coul,cutr,vcell,ict,lpotp1(ict),znuc(ict))
          rms=rms+(true-test)**2
          if(i.eq.1) then
            write(6,'(''vps'',f8.4,3f12.6,2f12.8,21x,f9.3,2f12.6)') rr,true,ewa,test,ewa-true,test-true,vs,vl
           else
            write(6,'(''vps'',f8.4,3f12.6,2f12.8,f12.6,2f9.3,2f12.6)') rr,true,ewa,test,ewa-true,test-true
     &      ,(true-true_s)/dx,(test-test_s)/dx,vs,vl
          endif
          true_s=true
  191   test_s=test
        rms=sqrt(rms/npts)
        write(6,'(''Rms error of psp fit (prim. cell)'',d12.4)') rms
        if(rms.gt.1.d-2) write(6,'(''Warning: rms error of psp fit too large'',d12.4)') rms
      endif
  195 continue

  197 znuc_sum=0
      znuc2_sum=0
      do 200 i=1,ncent
        znuc_sum=znuc_sum+znuc(iwctype(i))
  200   znuc2_sum=znuc2_sum+znuc(iwctype(i))**2

c     call pot_nn_ewald_old(cent,znuc,iwctype,ncent,pecent)
c     c_madelung=pecent*dist_nn/(znuc(1)*znuc(2)*ncent/2)
c     write(6,'(''pecent (old)='',f10.6)') pecent
c     write(6,'(''c_madelung_o='',f10.6)') c_madelung

c We do not really need to call pot_nn_ewald since it is called
c from read_input via pot_nn later on anyway.
      call pot_nn_ewald(cent,znuc,iwctype,ncent,pecent)
c     c_madelung=pecent*dist_nn/(znuc(1)*znuc(2)*ncent/2)
      write(6,'(''pecent='',f13.6)') pecent
c     write(6,'(''c_madelung='',f10.6)') c_madelung

      return
      end
c-----------------------------------------------------------------------

      subroutine short_distance(vector,volume,dist_min,distcell)
c Written by Cyrus Umrigar
c distcell(i) is the perpendicular distance between cell faces parallel
c to the other 2 directions from i.
c dist_min is the shortest of these three.
c By choosing the range of the short-range part of the Ewald sums to be
c <= half the shortest perpendicular distance we ensure that the short-range
c part has zero or one terms.

      implicit real*8(a-h,o-z)
      dimension vector(3,3),v1(3),v2(3),v3(3),distcell(3)

      v1(1)=vector(1,2)
      v1(2)=vector(2,2)
      v1(3)=vector(3,2)

      v2(1)=vector(1,3)
      v2(2)=vector(2,3)
      v2(3)=vector(3,3)

      call cross(v1,v2,v3)
      vlen=sqrt(v3(1)**2+v3(2)**2+v3(3)**2)
      distcell(1)=volume/vlen
      dist_min=distcell(1)

      v1(1)=vector(1,3)
      v1(2)=vector(2,3)
      v1(3)=vector(3,3)

      v2(1)=vector(1,1)
      v2(2)=vector(2,1)
      v2(3)=vector(3,1)

      call cross(v1,v2,v3)
      vlen=sqrt(v3(1)**2+v3(2)**2+v3(3)**2)
      distcell(2)=volume/vlen
      dist_min=min(dist_min,distcell(2))

      v1(1)=vector(1,1)
      v1(2)=vector(2,1)
      v1(3)=vector(3,1)

      v2(1)=vector(1,2)
      v2(2)=vector(2,2)
      v2(3)=vector(3,2)

      call cross(v1,v2,v3)
      vlen=sqrt(v3(1)**2+v3(2)**2+v3(3)**2)
      distcell(3)=volume/vlen
      dist_min=min(dist_min,distcell(3))

      return
      end
c-----------------------------------------------------------------------

      subroutine cross(v1,v2,v3)
c evaluates the cross-product of v1 and v2 and puts it in v3

      implicit real*8(a-h,o-z)

      dimension v1(3),v2(3),v3(3)

      v3(1) = v1(2) * v2(3) - v1(3) * v2(2)
      v3(2) = v1(3) * v2(1) - v1(1) * v2(3)
      v3(3) = v1(1) * v2(2) - v1(2) * v2(1)

      return
      end
c-----------------------------------------------------------------------

      subroutine shells(cutg,glatt,gdist,igvec,gvec,gnorm,igmult,ngvec_big,
     & ngnorm_big,ng1d,icell)
c Written by Cyrus Umrigar

c icell = 0  primitive cell
c         1  simulation cell

      implicit real*8(a-h,o-z)

      include 'ewald.h'

      common /dim/ ndim
      dimension glatt(3,*),gdist(3),igvec(3,*),gvec(3,*),gnorm(*),igmult(*),ng1d(*)
      dimension gnorm_tmp(NGVEC_SIM_BIGX)

      do 1 k=1,ndim
    1   ng1d(k)=int(cutg/gdist(k))

      cutg2=cutg**2
      ngvec_big=0
c     do 10 i1=-ng1d(1),ng1d(1)
      do 10 i1=0,ng1d(1)
        if(i1.ne.0) then
          i2min=-ng1d(2)
         else
          i2min=0
        endif
c       do 10 i2=-ng1d(2),ng1d(2)
        do 10 i2=i2min,ng1d(2)
          if(i2.ne.0.or.i1.ne.0) then
            i3min=-ng1d(3)
           else
            i3min=0
          endif
c         do 10 i3=-ng1d(3),ng1d(3)
          do 10 i3=i3min,ng1d(3)

            gx=i1*glatt(1,1)+i2*glatt(1,2)+i3*glatt(1,3)
            gy=i1*glatt(2,1)+i2*glatt(2,2)+i3*glatt(2,3)
            gz=i1*glatt(3,1)+i2*glatt(3,2)+i3*glatt(3,3)

            glen2=gx*gx+gy*gy+gz*gz

            if(glen2.le.cutg2) then
              ngvec_big=ngvec_big+1
              if(icell.eq.0 .and. ngvec_big.gt.NGVEC_BIGX) then
                stop 'ngvec_big > NGVEC_BIGX in shells'
               elseif(icell.eq.1 .and. ngvec_big.gt.NGVEC_SIM_BIGX) then
                stop 'ngvec_big > NGVEC_SIM_BIGX in shells'
              endif

              igvec(1,ngvec_big)=i1
              igvec(2,ngvec_big)=i2
              igvec(3,ngvec_big)=i3

              gvec(1,ngvec_big)=gx
              gvec(2,ngvec_big)=gy
              gvec(3,ngvec_big)=gz

              gnorm_tmp(ngvec_big)=dsqrt(glen2)
            endif
   10 continue

      call sort(igvec,gvec,gnorm_tmp,gnorm,igmult,ngvec_big,ngnorm_big,icell)

      return
      end
c-----------------------------------------------------------------------

      subroutine sort(igvec,gvec,gnorm_tmp,gnorm,igmult,ngvec_big,ngnorm_big,icell)
      implicit real*8(a-h,o-z)
c Written by Cyrus Umrigar
c Use Shell-Metzger sort to put g-vectors in some standard order, so that
c the order they appear in is independent of cutg_sim_big.

      parameter(eps=1.d-12)

      include 'ewald.h'

      common /dim/ ndim
      dimension igvec(3,*),gvec(3,*),gnorm_tmp(*),gnorm(*),igmult(*)

      cost(igv1,igv2,igv3,gn)=igv3+10.d0**4*igv2+10.d0**8*igv1+10.d0**12*gn

      lognb2=int(dlog(dfloat(ngvec_big))/dlog(2.d0)+1.d-14)
      m=ngvec_big
      do 20 nn=1,lognb2
        m=m/2
        k=ngvec_big-m
        do 20 j=1,k
          do 10 i=j,1,-m
            l=i+m
c           if(gnorm_tmp(l).gt.gnorm_tmp(i)-eps) goto 20
            if(cost(igvec(1,l),igvec(2,l),igvec(3,l),gnorm_tmp(l)).gt.cost(igvec(1,i),igvec(2,i),igvec(3,i),gnorm_tmp(i))) goto 20
            t=gnorm_tmp(i)
            gnorm_tmp(i)=gnorm_tmp(l)
            gnorm_tmp(l)=t
            do 10 k=1,ndim
              it=igvec(k,i)
              igvec(k,i)=igvec(k,l)
              igvec(k,l)=it
              t=gvec(k,i)
              gvec(k,i)=gvec(k,l)
   10         gvec(k,l)=t
   20     continue

c figure out the multiplicities and convert gnorm from being ngvec_big long to being ngnorm_big long
      ngnorm_big=1
      icount=0
      do 30 i=2,ngvec_big
        icount=icount+1
        if(gnorm_tmp(i)-gnorm_tmp(i-1).gt.eps) then
          igmult(ngnorm_big)=icount
          gnorm(ngnorm_big)=gnorm_tmp(i-1)
          ngnorm_big=ngnorm_big+1
          if(icell.eq.0 .and. ngnorm_big.gt.NGNORM_BIGX) then
            write(6,'(''ngnorm_big,NGNORM_BIGX='',2i8)') ngnorm_big
            stop 'ngnorm_big > NGNORM_BIGX in sort'
           elseif(icell.eq.1 .and. ngnorm_big.gt.NGNORM_SIM_BIGX) then
            write(6,'(''ngnorm_sim_big,NGNORM_SIM_BIGX='',2i8)') ngnorm_big,NGNORM_SIM_BIGX
            stop 'ngnorm_sim_big > NGNORM_SIM_BIGX in sort'
          endif
          icount=0
        endif
   30 continue
      igmult(ngnorm_big)=icount+1
      gnorm(ngnorm_big)=gnorm_tmp(ngvec_big)

      icheck=0
      do 40 i=1,ngnorm_big
   40   icheck=icheck+igmult(i)
      if(icheck.ne.ngvec_big) stop 'problem in sort'

c     j=0
c     do 100 i=1,ngnorm_big
c       do 100 im=1,igmult(i)
c         j=j+1
c 100     write(6,'(''CHECK '',2i4,9f10.4)')
c    &    i,igmult(i),gnorm(i),(gvec(k,j),k=1,ndim)
c     write(6,*)

      return
      end
c-----------------------------------------------------------------------

      subroutine k_vectors
c Written by Cyrus Umrigar
c Generate the unique k-vectors, i.e., those that are not related by a
c primitive cell reciprocal lattice vector and are not the inverses of
c existing vectors.  Note that for the moment we keep vectors that are
c related by primitive cell reciprocal lattice vectors to inverses of
c other vectors.  We should come back to the issue of whether that is
c a symmetry one could use later on.

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'
      parameter (eps=1.d-6)

      common /dim/ ndim
      common /periodic/ rlatt(3,3),glatt(3,3),rlatt_sim(3,3),glatt_sim(3,3)
     &,rlatt_inv(3,3),rlatt_sim_inv(3,3),glatt_inv(3,3)
     &,cutr,cutr_sim,cutg,cutg_sim,cutg_big,cutg_sim_big
     &,igvec(3,NGVEC_BIGX),gvec(3,NGVEC_BIGX),gnorm(NGNORM_BIGX),igmult(NGNORM_BIGX)
     &,igvec_sim(3,NGVEC_SIM_BIGX),gvec_sim(3,NGVEC_SIM_BIGX),gnorm_sim(NGNORM_SIM_BIGX),igmult_sim(NGNORM_SIM_BIGX)
     &,rkvec_shift(3),kvec(3,MKPTS),rkvec(3,MKPTS),rknorm(MKPTS)
     &,k_inv(MKPTS),nband(MKPTS),ireal_imag(MORB)
     &,znuc_sum,znuc2_sum,vcell,vcell_sim
     &,ngnorm,ngvec,ngnorm_sim,ngvec_sim,ngnorm_orb,ngvec_orb,nkvec
     &,ngnorm_big,ngvec_big,ngnorm_sim_big,ngvec_sim_big
     &,ng1d(3),ng1d_sim(3),npoly,ncoef,np,isrange

      dimension rkvec_try(3),rkvec_latt(3)

      k_inv(1)=1
      do 10 k=1,ndim
        kvec(k,1)=0
   10   rkvec(k,1)=rkvec_shift(k)
c     write(6,'(''k-vec( 1)='',3i5,3f9.4)') (kvec(k,1),k=1,ndim),(rkvec(k,1),k=1,ndim)

      nkvec=0
c Warning: Need to think more about do loop limit
c     do 120 i=1,min(ngvec_sim,vcell_sim*NSYM/vcell)
      do 120 i=1,min(ngvec_sim,nint(8*vcell_sim/vcell))
c     do 120 i=1,ngvec_sim
        do 20 k=1,ndim
   20     rkvec_try(k)=rkvec_shift(k)+gvec_sim(k,i)
c Check if after translation by primitive cell reciprocal lattice vector it is
c the same as an existing k-vector
        do 50 j=2,ngvec
          do 50 l=1,nkvec
            rnorm=0
            do 30 k=1,ndim
   30         rnorm=rnorm+(rkvec_try(k)-gvec(k,j)-rkvec(k,l))**2
            if(rnorm.lt.eps) goto 120
            rnorm=0
            do 40 k=1,ndim
   40         rnorm=rnorm+(rkvec_try(k)+gvec(k,j)-rkvec(k,l))**2
            if(rnorm.lt.eps) goto 120
   50   continue
c Check if after translation by some primitive cell reciprocal lattice vector G it is
c the inverse of an existing k-vector, or equivalently if there exists G such that k=G/2.
c If yes, then k and -k give only one indep. state, else they give two.
        do 80 j=2,ngvec
          do 80 l=1,nkvec
            rnorm=0
            do 60 k=1,ndim
   60         rnorm=rnorm+(rkvec_try(k)-gvec(k,j)+rkvec(k,l))**2
            if(rnorm.lt.eps) then
              k_inv(l)=2
              goto 120
            endif
            rnorm=0
            do 70 k=1,ndim
   70         rnorm=rnorm+(rkvec_try(k)+gvec(k,j)+rkvec(k,l))**2
            if(rnorm.lt.eps) then
              k_inv(l)=2
              goto 120
            endif
   80   continue
c Voila, found a new one
        nkvec=nkvec+1
        if(nkvec.gt.MKPTS) stop 'nkvec > MKPTS in k_vectors'
        k_inv(nkvec)=1
        rknorm(nkvec)=0
        do 110 k=1,ndim
          kvec(k,nkvec)=igvec_sim(k,i)
          rkvec(k,nkvec)=rkvec_try(k)
  110     rknorm(nkvec)=rknorm(nkvec)+rkvec_try(k)**2
        rknorm(nkvec)=sqrt(rknorm(nkvec))
c       write(6,'(''k-vec('',i2,'')='',3i5,3f9.4,f11.6)') nkvec,(kvec(k,nkvec),k=1,ndim),(rkvec(k,nkvec),k=1,ndim),rknorm(nkvec)
  120 continue

c Sort into some standard order independent of cutg_sim_big
      call sort_kvec(k_inv,kvec,rkvec,rknorm,nkvec)

c I could just get out of the above loop after finding vcell_sim/vcell
c but instead do check after loop to be safe.
      write(6,'(/,''k-vector k-inv      kvec               rkvec'')')
      nkvec_tot=0
      do 130 i=1,nkvec
        nkvec_tot=nkvec_tot+k_inv(i)
  130   write(6,'(''k-vec('',i2,'')='',i2,2x,3i4,2x,3f14.10,f11.6)') i,k_inv(i),(kvec(k,i),k=1,ndim),(rkvec(k,i),k=1,ndim)
     &,rknorm(i)
      write(6,'(''nkvec,nkvec_tot='',2i5)') nkvec,nkvec_tot

c Write out k-pts in reciprocal lattice units and wts for input to pw program
      write(6,'(/,i2,'' k-vectors (shifted) in recip. latt. units, and wts, for input to pw program'')') nkvec
      do 150 ikv=1,nkvec
        do 140 k=1,ndim
          rkvec_latt(k)=0
          do 140 i=1,ndim
  140       rkvec_latt(k)=rkvec_latt(k)+glatt_inv(k,i)*rkvec(i,ikv)
c 150 write(6,'(''k-vec('',i2,'')='',i2,2x,3f14.10)') ikv,k_inv(ikv),(rkvec_latt(k),k=1,ndim)
  150 write(6,'(''k-vec('',i2,'')='',3f14.10,f4.0)') ikv,(rkvec_latt(k),k=1,ndim),dfloat(k_inv(ikv))

      if(nkvec_tot.ne.nint(vcell_sim/vcell)) then
        write(6,'(''Warning: nkvec != vcell_sim/vcell'',9i5)') nkvec_tot,nint(vcell_sim/vcell)
        write(6,'(''Possibly the primitive and simulation cells are not commensurate, or cutg needs to be bigger'')')
        if(nkvec_tot.lt.nint(vcell_sim/vcell))
     &  stop 'You probably need to increase limit of 120 loop if nkvec_tot < vcell_sim/vcell'
        if(nkvec_tot.gt.nint(vcell_sim/vcell))
     &  stop 'You probably need to increase cutg rel. to cutg_sim if nkvec_tot > vcell_sim/vcell'
      endif

      return
      end
c-----------------------------------------------------------------------
      subroutine sort_kvec(k_inv,kvec,rkvec,rknorm,nkvec)
c Written by Cyrus Umrigar
c Use Shell-Metzger sort to put k-vectors in some standard order, so that
c the order they appear in is independent of cutg_sim_big.

      implicit real*8(a-h,o-z)

      include 'ewald.h'

      common /dim/ ndim
      dimension k_inv(*),kvec(3,*),rkvec(3,*),rknorm(*)
      cost(kv1,kv2,kv3,rk)=kv3+10.d0**4*kv2+10.d0**8*kv1+10.d0**12*rk

      lognb2=int(dlog(dfloat(nkvec))/dlog(2.d0)+1.d-14)
      m=nkvec
      do 20 nn=1,lognb2
        m=m/2
        k=nkvec-m
        do 20 j=1,k
          do 10 i=j,1,-m
            l=i+m
            if(cost(kvec(1,l),kvec(2,l),kvec(3,l),rknorm(l)).gt.cost(kvec(1,i),kvec(2,i),kvec(3,i),rknorm(i))) goto 20
            it=k_inv(i)
            k_inv(i)=k_inv(l)
            k_inv(l)=it
            t=rknorm(i)
            rknorm(i)=rknorm(l)
            rknorm(l)=t
            do 10 k=1,ndim
              it=kvec(k,i)
              kvec(k,i)=kvec(k,l)
              kvec(k,l)=it
              t=rkvec(k,i)
              rkvec(k,i)=rkvec(k,l)
   10         rkvec(k,l)=t
   20     continue

      return
      end
c-----------------------------------------------------------------------

      subroutine fourier_transform(r,arg_ps,r0_ps,nr,vps_short,vcell,gnorm,
     & ngnorm_big,vbare_psp)
c Written by Cyrus Umrigar and Claudia Filippi

c Note: vps_short overwritten
c g > 0 (4pi/vcell)*(int r*vps_short*sin(g*r)*dr)/g
c g = 0 (4pi/vcell)*(int r*2*vps_short*dr)

      implicit real*8(a-h,o-z)

      include 'ewald.h'
      include 'pseudo.h'

      common /constant/ twopi

      dimension r(*),vps_short(*),gnorm(*),y(MPS_GRID),vbare_psp(NGNORM_BIGX)

      anorm=2*twopi/vcell

c shifted exponential grid
      rlogarg=dlog(arg_ps)
      do 10 ir=1,nr
   10   vps_short(ir)=(r(ir)+r0_ps)*vps_short(ir)*rlogarg

      dx=1.d0
c g != 0 components
      do 30 ig=2,ngnorm_big
        do 20  ir=1,nr
   20     y(ir)=r(ir)*vps_short(ir)*sin(gnorm(ig)*r(ir))
        call simson(y,vbare_psp(ig),dx,nr)
c       nrr=((nr-1)/4)*4+1
c       vbare_psp(ig)=bode(y,dx,nrr)
   30   vbare_psp(ig)=anorm*vbare_psp(ig)/gnorm(ig)

c g=0 component
      do 40  ir=1,nr
   40   y(ir)=r(ir)*r(ir)*vps_short(ir)
      call simson(y,vbare_psp(1),dx,nr)
      vbare_psp(1)=anorm*vbare_psp(1)

      return
      end
c-----------------------------------------------------------------------
      subroutine separate(v,b0,lowest_pow,ngnorm_big,igmult,gnorm,ngnorm
     &,cutr,vcell,ncoef,np,b,y,chisq,nconstraint,isrange)
c Written by Cyrus Umrigar and Claudia Filippi

      implicit real*8(a-h,o-z)

c     parameter(NPX=6)
      parameter(d15b8=15.d0/8.d0,d5b4=5.d0/4.d0,d3b8=3.d0/8.d0)
      parameter(d35b16=35.d0/16.d0,d21b16=21.d0/16.d0,d5b16=5.d0/16.d0)
      parameter(d693b256=693.d0/256.d0,d1155b256=1155.d0/256.d0,d693b128=693.d0/128.d0
     &,d495b128=495.d0/128.d0,d385b256=385.d0/256.d0,d63b256=63.d0/256.d0)
c                      693           1155            693           495
c Out[24]= {{t[1] -> -(---), t[2] -> ----, t[3] -> -(---), t[4] -> ---,
c                      256           256             128           128
c 
c                 385           63
c       t[5] -> -(---), t[6] -> ---}}
c                 256           256

      common /constant/ twopi

      include 'ewald.h'

      dimension a(NCOEFX,NCOEFX),c(NCOEFX+NPX),work(NCOEFX)
      dimension v(*),b(*),y(*),igmult(*),gnorm(*)

      if(ncoef+np.gt.NCOEFX+NPX) stop 'ncoef+np > NCOEFX+NPX in separate'

      anorm=2*twopi*cutr**3/vcell

c reduce number of free parameters due to constraints and shift the
c pointer to the first parameter to be optimized.
      nfree=ncoef-nconstraint
      i0=1+nconstraint

      write(6,'(/,''Ncoef ='',i5)') ncoef

c zero right and left hand side of fitting equation
      do 10 i=1,ncoef
        b(i)=0.d0
        do 10 j=1,ncoef
   10     a(j,i)=0.d0

      chisq=0.d0
c go over k values larger than those explicitly used
      do 20 k=ngnorm+1,ngnorm_big
        gr=gnorm(k)*cutr
        ig=k
        if(isrange.eq.0) then
          call integral_sin_poly(gr,lowest_pow,ncoef,np,anorm,c)
         elseif(isrange.eq.1) then
          call integral_sin_poly1(gr,ig,lowest_pow,ncoef,np,anorm,c)
         elseif(isrange.eq.4) then
          call integral_sin_poly4(gr,lowest_pow,ncoef,np,anorm,c)
        endif

c Constraints.
c nconstraint=2 imposes that linear part of vsrange 1/r is zero.
        if(isrange.le.3) then
          if(nconstraint.eq.2) then
            vk=v(k)-beta1*(c(1)+0.5d0*(np-1)*c(2))
            c(3)=c(3)+c(2)/np
           else
            vk=v(k)-beta1*c(1)
          endif
c   Constraint for cusp.
          c(2)=c(2)+beta2*c(1)
         elseif(isrange.eq.4) then
          if(nconstraint.eq.1) then
            cutri=1/cutr
            vk=v(k)-cutri*c(1)
           elseif(nconstraint.eq.5) then
            cutri=1/cutr
            vk=v(k)+cutri*(-c(1)+d35b16*c(2)-d35b16*c(3)+d21b16*c(4)-d5b16*c(5))
            c(6)=c(2)-4*c(3)+6*c(4)-4*c(5)+c(6)
            c(7)=4*c(2)-15*c(3)+20*c(4)-10*c(5)+c(7)
            c(8)=10*c(2)-36*c(3)+45*c(4)-20*c(5)+c(8)
            c(9)=20*c(2)-70*c(3)+84*c(4)-35*c(5)+c(9)
          endif
        endif

c       write(6,'(''vk='',i4,9d12.4)') k,v(k),beta1*c(1),(c(i),i=1,3)

        chisq=chisq+igmult(k)*vk**2

c add to right hand side
        do 20 i=i0,ncoef
          b(i)=b(i)+igmult(k)*vk*c(i)
c add to left hand side
          do 20 j=i0,ncoef
   20       a(j,i)=a(j,i)+igmult(k)*c(i)*c(j)

c     write(6,'(''a='',10d14.5)') ((a(i,j),i=i0,ncoef),j=i0,ncoef)
c     write(6,'(''b='',10d14.5)') (b(i),i=i0,ncoef)

c factor matrix a
      if(nfree.gt.0) then
        call dpoco(a(i0,i0),NCOEFX,nfree,rcond,work,info)
        write(6,'(''condition #, rcond, after return from dpoco'',d12.4)') rcond
        if(info.ne.0) write(6,'(''the leading minor of order'',i3,'' is singular'')') info
        if(rcond.lt.1.d-14) stop 'rcond too small in dpoco'
        if(info.ne.0) stop 'info in dpoco.ne.0 when called from separate'
      endif

c make a spare copy of right hand side
      do 30 i=i0,ncoef
   30   work(i)=b(i)


c solve linear equations
      if(nfree.gt.0) call dposl(a(i0,i0),NCOEFX,nfree,b(i0))
c     write(6,*) (b(i),i=i0,ncoef)

c b is now the solution (t in Ceperley's paper)
      do 40 i=i0,ncoef
   40   chisq=chisq-work(i)*b(i)
c     if(chisq.gt.0) then
c       write(6,'(''Rms error '',d12.5)') dsqrt(chisq)
c      else
c       write(6,'(''Warning: Rms error missing, chisq negative in separate'',d12.4)') chisq
c       if(chisq.lt.0.d0) stop 'chisq<0 in separate'
c     endif

      if(isrange.le.3) then
c beta2 !=0 only for cusp constraint
        if(nconstraint.eq.1) then
          b(1)=beta1+beta2*b(2)
c nconstraint=2 imposes that linear part of vsrange 1/r is zero.
         elseif(nconstraint.eq.2) then
          b(1)=beta1
          b(2)=0.5d0*(np-1)*b(1)+b(3)/np
        endif
       elseif(isrange.eq.4) then
        cutri=1/cutr
        b(1)=cutri

c       b(2)=-d15b8*cutri
c       b(3)=d5b4*cutri
c       b(4)=-d3b8*cutri
c       b(5)=0

c       b(2)=-d35b16*cutri
c       b(3)=d35b16*cutri
c       b(4)=-d21b16*cutri
c       b(5)=d5b16*cutri

        if(nconstraint.eq.5) then
          b(2)=-d35b16*cutri+b(6)+4*b(7)+10*b(8)+20*b(9)
          b(3)=d35b16*cutri-4*b(6)-15*b(7)-36*b(8)-70*b(9)
          b(4)=-d21b16*cutri+6*b(6)+20*b(7)+45*b(8)+84*b(9)
          b(5)=d5b16*cutri-4*b(6)-10*b(7)-20*b(8)-35*b(9)
         elseif(nconstraint.eq.7) then
          b(2)=-d693b256*cutri
          b(3)=d1155b256*cutri
          b(4)=-d693b128*cutri
          b(5)=d495b128*cutri
          b(6)=-d385b256*cutri
          b(7)=d63b256*cutri
        endif
      endif

      write(6,*) (b(i),i=1,ncoef)

c subtract effect of short range potential on fourier components

      rms2=0
      do 70 k=1,ngnorm_big
        gr=gnorm(k)*cutr
        ig=k
        if(isrange.eq.0) then
          call integral_sin_poly(gr,lowest_pow,ncoef,np,anorm,c)
         elseif(isrange.eq.1) then
          call integral_sin_poly1(gr,ig,lowest_pow,ncoef,np,anorm,c)
         elseif(isrange.eq.4) then
          call integral_sin_poly4(gr,lowest_pow,ncoef,np,anorm,c)
        endif
c       write(6,'(''vk2='',i4,9d12.4)') k,v(k),b(1)*c(1),(c(i),i=1,3)
        if(k.le.ngnorm) then
        y(k)=v(k)
        do 50 i=1,ncoef
   50     y(k)=y(k)-c(i)*b(i)
        else
        tmp=v(k)
        do 60 i=1,ncoef
   60     tmp=tmp-c(i)*b(i)
        rms2=rms2+igmult(k)*tmp**2
        endif
   70 continue
      rms2=sqrt(rms2)
c     write(6,'(''rms,rms2='',2d12.5)') sqrt(chisq),rms2

c     write(6,'(/,''Poly coefs (t) = '',5d14.6)') (b(i),i=1,ncoef)
      write(6,'(/,''vk = '',20d12.4)') (v(k),k=1,ngnorm)
      write(6,'(/,''Yk = '',20d12.4)') (y(k),k=1,ngnorm)

      return
      end
c-----------------------------------------------------------------------

      subroutine integral_sin_poly(g,lowest_pow,ncoef,np,anorm,c)
c Written by Cyrus Umrigar and Claudia Filippi
c anorm = 4*pi*cutr^3/volume
c g = g*cutr
c x = r/cutr
c output coefficients c

      implicit real*8(a-h,o-z)
      complex*16 ti,et,em

      parameter(NPTS=1001)
      dimension c(*)
c     dimension c(*),y(NPTS)

c integrates sin(g*x)*x**i for i=lowest_pow+1 to ncoef+np+lowest_pow and x from 0 to 1
      if(dabs(g).gt.1.d-10) then
        gi=1.d0/g
        ti=dcmplx(0.d0,-gi)
        et=dcmplx(dsin(g)*gi,-dcos(g)*gi)
        em=ti*(et-ti)
        do 10 i=1,ncoef+np+lowest_pow+1
          if(i.gt.lowest_pow+1) c(i-lowest_pow-1)=dreal(em)
   10     em=ti*(et-i*em)
       else
        do 20 i=1,ncoef+np+lowest_pow+1
   20     c(i)=1.d0/(i+2+lowest_pow)
      endif

c take care that expansion functions are h_i(x) = x**i*(1-x)**np
c Warning check if we need to go one more.
      do 30 k=1,np
        do 30 i=1,ncoef+np-k
   30     c(i)=c(i)-c(i+1)

c     write(6,'(''g,c1='',f5.1,9f9.5)') g,(c(i),i=1,ncoef)

c Calculate c from numerical integral rather than recursion for small non-zero g's
c to check eval above.  Agrees well.
c      if(g.ne.0.d0 .and. g.lt.10.d0) then
c      dx=1.d0/(NPTS-1)
c      do 36 i=1,ncoef
c        do 35 j=1,NPTS
c          x=(j-1)*dx
c          if(g.gt.1.d-9) then
c            if(i+lowest_pow.ne.0) then
c              y(j)=x**(i+lowest_pow)*(1-x)**np*sin(g*x)
c             else
c              y(j)=(1-x)**np*sin(g*x)
c            endif
c           else
c            y(j)=x**(i+1+lowest_pow)*(1-x)**np
c          endif
c  35    continue
c        c(i)=bode(y,dx,NPTS)
c        if(g.gt.1.d-6) then
c          c(i)=c(i)/g
c        endif
c  36 continue

cc    write(6,'(''g,c2='',f5.1,9f9.5)') g,(c(i),i=1,ncoef)
c     endif

c multiply by anorm
      do 40 i=1,ncoef
   40   c(i)=anorm*c(i)

      return
      end
c-----------------------------------------------------------------------

      subroutine integral_sin_poly1(g,ig,lowest_pow,ncoef,np,anorm,c)
c Written by Cyrus Umrigar and Claudia Filippi
c anorm = 4*pi*cutr^3/volume
c g = g*cutr
c x = r/cutr
c output coefficients c

      implicit real*8(a-h,o-z)
      complex*16 ti,et,em

      include 'ewald.h'
      parameter(NPTS=1001)

      common /ewald_basis/ vps_basis_fourier(NGNORM_BIGX)
      dimension c(*)
c     dimension c(*),y(NPTS)

c integrates sin(g*x)*x**i for i=lowest_pow+1 to ncoef+np+lowest_pow and x from 0 to 1
      if(dabs(g).gt.1.d-10) then
        gi=1.d0/g
        ti=dcmplx(0.d0,-gi)
        et=dcmplx(dsin(g)*gi,-dcos(g)*gi)
        em=ti*(et-ti)
        do 10 i=1,ncoef+np+lowest_pow+1
          if(i.gt.lowest_pow+1) c(i-lowest_pow-1)=dreal(em)
   10     em=ti*(et-i*em)
       else
        do 20 i=1,ncoef+np+lowest_pow+1
   20     c(i)=1.d0/(i+2+lowest_pow)
      endif

c take care that expansion functions are h_i(x) = x**i*(1-x)**np
c Warning check if we need to go one more.
      do 30 k=1,np
c       do 30 i=1,ncoef+np-k
        do 30 i=1,ncoef+np-k-1
   30     c(i)=c(i)-c(i+1)

      if(ncoef.gt.0) c(ncoef)=vps_basis_fourier(ig)

c     write(6,'(''g,c1='',f5.1,9f9.5)') g,(c(i),i=1,ncoef)

c Calculate c from numerical integral rather than recursion for small non-zero g's
c      if(g.ne.0.d0 .and. g.lt.10.d0) then
c      dx=1.d0/(NPTS-1)
cc     do 36 i=1,ncoef
c      do 36 i=1,ncoef-1
c        do 35 j=1,NPTS
c          x=(j-1)*dx
c          if(g.gt.1.d-6) then
c            y(j)=x**(i+lowest_pow)*(1-x)**np*sin(g*x)
c           else
c            y(j)=x**(i+1+lowest_pow)*(1-x)**np
c          endif
c  35    continue
c        c(i)=bode(y,dx,NPTS)
c        if(g.gt.1.d-6) then
c          c(i)=c(i)/g
c        endif
c  36 continue

cc    write(6,'(''g,c2='',f5.1,9f9.5)') g,(c(i),i=1,ncoef)
c     endif

c multiply by anorm
c     do 40 i=1,ncoef
      do 40 i=1,ncoef-1
   40   c(i)=anorm*c(i)

      return
      end
c-----------------------------------------------------------------------

      subroutine integral_sin_poly4(g,lowest_pow,ncoef,np,anorm,c)
c Written by Cyrus Umrigar
c anorm = 4*pi*cutr^3/volume
c g = g*cutr
c x = r/cutr
c output coefficients c

      implicit real*8(a-h,o-z)
      complex*16 ti,et,em

      parameter(NPTS=1001)
      dimension c(*)
c     dimension c(*),y(NPTS)

c integrates sin(g*x)*x**i for i=lowest_pow+1 to ncoef+np+lowest_pow and x from 0 to 1
      if(dabs(g).gt.1.d-10) then
        gi=1.d0/g
        ti=dcmplx(0.d0,-gi)
        et=dcmplx(dsin(g)*gi,-dcos(g)*gi)
        em=ti*(et-ti)
        do 10 i=1,16
          if(i.gt.lowest_pow+1) c(i-lowest_pow-1)=dreal(em)
   10     em=ti*(et-i*em)
       else
        do 20 i=1,16
   20     c(i)=1.d0/(i+2+lowest_pow)
      endif

c Shift them so that we save integrals for powers -1,0,2,4,6
      c(3)=c(4)
      c(4)=c(6)
      c(5)=c(8)
      c(6)=c(10)
      c(7)=c(12)
      c(8)=c(14)
      c(9)=c(16)

c     write(6,'(''g,c1='',f5.1,9f9.5)') g,(c(i),i=1,ncoef)

c Calculate c from numerical integral rather than recursion for small non-zero g's
c to check eval above.  Agrees well.
c      if(g.ne.0.d0 .and. g.lt.10.d0) then
c      dx=1.d0/(NPTS-1)
c      do 36 i=1,ncoef
c        do 35 j=1,NPTS
c          x=(j-1)*dx
c          if(g.gt.1.d-9) then
c            if(i+lowest_pow.ne.0) then
c              y(j)=x**(i+lowest_pow)*(1-x)**np*sin(g*x)
c             else
c              y(j)=(1-x)**np*sin(g*x)
c            endif
c           else
c            y(j)=x**(i+1+lowest_pow)*(1-x)**np
c          endif
c  35    continue
c        c(i)=bode(y,dx,NPTS)
c        if(g.gt.1.d-6) then
c          c(i)=c(i)/g
c        endif
c  36 continue

cc    write(6,'(''g,c2='',f5.1,9f9.5)') g,(c(i),i=1,ncoef)
c     endif

c multiply by anorm
      do 40 i=1,ncoef
   40   c(i)=anorm*c(i)

      return
      end
c-----------------------------------------------------------------------

      function choose(n,m)
c Written by Cyrus Umrigar
c Binomial coefficients ^nC_m
      implicit real*8(a-h,o-z)

      choose=1
      do 10 i=1,m
   10   choose=choose*(n-i+1)/dfloat(i)
      return
      end
c-----------------------------------------------------------------------

      function vsrange(r,cutr,lowest_pow,ncoef,np,b)
c Written by Cyrus Umrigar and Claudia Filippi
c h(x)= \sum_{i=1}^ncoef b_i x^{i-1} (1-x)^np, x=r/cutr

      implicit real*8(a-h,o-z)

      include 'ewald.h'

      dimension b(*)

      x=r/cutr

      vsrange=0
      if(x.gt.1.d0) return

      do 10 i=1,ncoef
   10   vsrange=b(ncoef-i+1)+x*vsrange

      vsrange=vsrange*(1-x)**np

      if(lowest_pow.eq.-1) vsrange=vsrange/x

      return
      end
c-----------------------------------------------------------------------

      function vsrange1(r,cutr,lowest_pow,ncoef,np,b,ict,l)
c Written by Cyrus Umrigar
c h(x)= \sum_{i=1}^ncoef b_i x^{i-1} (1-x)^np, x=r/cutr

      implicit real*8(a-h,o-z)

      include 'ewald.h'

      dimension b(*)

      x=r/cutr

      vsrange1=0
      if(x.gt.1.d0) return

c     do 10 i=1,ncoef
c  10   vsrange1=b(ncoef-i+1)+x*vsrange1
      do 10 i=1,ncoef-1
   10   vsrange1=b(ncoef-i)+x*vsrange1

      vsrange1=vsrange1*(1-x)**np

      call splfit_tm(r,l,ict,vpot)
c     write(6,'(''ict,l,r,vsrange1,vpot'',2i3,9f9.5)') ict,l,r,vsrange1,vpot
      vsrange1=vsrange1+b(ncoef)*vpot

c     if(lowest_pow.eq.-1) vsrange1=vsrange1/x

      return
      end
c-----------------------------------------------------------------------

      function vsrange4(r,cutr,lowest_pow,ncoef,np,b,ict,l)
c Written by Cyrus Umrigar
c h(x)= 1/r + \sum_{i=1}^4 b(1+i)*x^{2(i-1)},  x=r/cutr
c The b(i) are chosen so that h,h',h'',h''' =0 at x=1.
c Aside from the potential itself, the rest has only even powers at r=0
c as required by analyticity.

      implicit real*8(a-h,o-z)

      include 'ewald.h'

      dimension b(*)

      vsrange4=0
      if(r.ge.cutr) return

      x=r/cutr
c     xi=1/x
      x2=x*x
      x4=x2*x2
      x6=x4*x2
      x8=x6*x2
      x10=x8*x2
      x12=x10*x2
      x14=x12*x2

      if(lowest_pow.eq.-1) then
        vpot=1/r
       else
        call splfit_tm(r,l,ict,vpot)
      endif

c     write(6,'(''b='',9f9.5)') (b(i),i=1,7)
      vsrange4=vpot + b(2)+b(3)*x2+b(4)*x4+b(5)*x6+b(6)*x8+b(7)*x10
     &+b(8)*x12+b(9)*x14
      write(6,'(''4/r,vpot,vsrange4,r,cutr'',9f10.5)') 4/r,vpot,vsrange4,r,cutr

c     vsrange4=0
c     do 10 i=1,ncoef
c  10   vsrange4=b(ncoef-i+1)+x2*vsrange4
c     vsrange4=vsrange4+1/r

      return
      end
c-----------------------------------------------------------------------

      function ewald_pot(rvec,rr,gvec,gnorm,ngnorm,igmult,y,cutr,vcell)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'ewald.h'
      common /const/ pi,hb,etrial,delta,deltai,fbias,nelec,imetro,ipr

      dimension rvec(3),gvec(3,*),gnorm(*),igmult(*),y(*)

      gaus_exp=5/cutr
      ivec=1
c The factor of 2 in the next line is just to compensate for the 2 in the
c last line, which is there because we keep only half the vectors in the star.
      ewald_pot=-pi/(2*vcell*gaus_exp**2)
      do 10 k=2,ngnorm
        expon=exp(-(gnorm(k)/(2*gaus_exp))**2)
        do 10 im=1,igmult(k)
          ivec=ivec+1
          product=rvec(1)*gvec(1,ivec)+
     &            rvec(2)*gvec(2,ivec)+
     &            rvec(3)*gvec(3,ivec)
  10      ewald_pot=ewald_pot+cos(product)*y(k)*expon
      ewald_pot=2*ewald_pot+y(1)+derfc(gaus_exp*rr)/rr

      return
      end
c-----------------------------------------------------------------------

      function ewald_pot_psp(rvec,rr,gvec,gnorm,ngnorm,igmult,y,cutr,vcell,ict,l,z)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'ewald.h'
      common /const/ pi,hb,etrial,delta,deltai,fbias,nelec,imetro,ipr

      dimension rvec(3),gvec(3,*),gnorm(*),igmult(*),y(*)

      gaus_exp=5/cutr
      ivec=1
c The factor of 2 in the next line is just to compensate for the 2 in the
c last line, which is there because we keep only half the vectors in the star.
      ewald_pot_psp=-pi/(2*vcell*gaus_exp**2)
      do 10 k=2,ngnorm
        expon=exp(-(gnorm(k)/(2*gaus_exp))**2)
        do 10 im=1,igmult(k)
          ivec=ivec+1
          product=rvec(1)*gvec(1,ivec)+
     &            rvec(2)*gvec(2,ivec)+
     &            rvec(3)*gvec(3,ivec)
  10      ewald_pot_psp=ewald_pot_psp+cos(product)*y(k)*expon
      call splfit_tm(rr,l,ict,vpot)
c     write(6,'(''rr,ewald_pot_psp'',f8.4,9f9.5)') rr,-z*(2*ewald_pot_psp+y(1)),vpot,-z*(2*ewald_pot_psp+y(1))+vpot
      ewald_pot_psp=-z*(2*ewald_pot_psp+y(1))+vpot

      return
      end
c-----------------------------------------------------------------------
      function vlrange_old(rvec,gvec,ngnorm,igmult,y)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'ewald.h'

      dimension rvec(3),gvec(3,*),igmult(*),y(*)
c     dimension rvec(3),gvec(3,NGVEC_SIM_BIGX),igmult(NGNORM_SIM_BIGX),y(NGNORM_SIM_BIGX)

      ivec=1
      vlrange=0
      do 10 k=2,ngnorm
        do 10 im=1,igmult(k)
          ivec=ivec+1
          product=rvec(1)*gvec(1,ivec)+
     &            rvec(2)*gvec(2,ivec)+
     &            rvec(3)*gvec(3,ivec)
  10      vlrange=vlrange+cos(product)*y(k)
      vlrange_old=2*vlrange+y(1)

      return
      end
c-----------------------------------------------------------------------

      function vlrange_nn_old2(ncent,znuc,iwctype,ngnorm,igmult,cos_g,sin_g,y)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      dimension znuc(*),iwctype(*),igmult(*),cos_g(MELEC,*),sin_g(MELEC,*),y(*)

      ivec=1
      vl=0
      do 70 k=2,ngnorm
        do 70 im=1,igmult(k)
          ivec=ivec+1
          cos_sum=0
          sin_sum=0
          do 60 i=1,ncent
            znuci=znuc(iwctype(i))
            cos_sum=cos_sum+znuci*cos_g(i,ivec)
   60       sin_sum=sin_sum+znuci*sin_g(i,ivec)
   70     vl=vl+y(k)*(cos_sum**2+sin_sum**2)
      vlrange_nn_old2=vl

      return
      end
c-----------------------------------------------------------------------

      function vlrange_ee_old2(nelec,ngnorm,igmult,cos_g,sin_g,y)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      dimension igmult(*),cos_g(MELEC,*),sin_g(MELEC,*),y(*)

      ivec=1
      vl=0
      do 70 k=2,ngnorm
        do 70 im=1,igmult(k)
          ivec=ivec+1
          cos_sum=0
          sin_sum=0
          do 60 i=1,nelec
            cos_sum=cos_sum+cos_g(i,ivec)
   60       sin_sum=sin_sum+sin_g(i,ivec)
   70     vl=vl+y(k)*(cos_sum**2+sin_sum**2)
      vlrange_ee_old2=vl

      return
      end
c-----------------------------------------------------------------------

      function vlrange(ngnorm,igmult,cos1_sum,cos2_sum,sin1_sum,sin2_sum,y)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      dimension igmult(*),cos1_sum(*),cos2_sum(*),sin1_sum(*),sin2_sum(*),y(*)

      ivec=1
      vl=0.5d0*y(1)*(cos1_sum(1)*cos2_sum(1)+sin1_sum(1)*sin2_sum(1))
      do 70 k=2,ngnorm
        do 70 im=1,igmult(k)
          ivec=ivec+1
   70     vl=vl+y(k)*(cos1_sum(ivec)*cos2_sum(ivec)+sin1_sum(ivec)*sin2_sum(ivec))
      vlrange=vl

      return
      end
c-----------------------------------------------------------------------

      function vlrange_p(ngnorm,igmult,cos1_sum,cos2_sum,sin1_sum,sin2_sum)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      dimension igmult(*),cos1_sum(*),cos2_sum(*),sin1_sum(*),sin2_sum(*)

      ivec=1
      vl=0.5d0*(cos1_sum(1)*cos2_sum(1)+sin1_sum(1)*sin2_sum(1))
      do 70 k=2,ngnorm
        do 70 im=1,igmult(k)
          ivec=ivec+1
   70     vl=vl+(cos1_sum(ivec)*cos2_sum(ivec)+sin1_sum(ivec)*sin2_sum(ivec))
      vlrange_p=vl

      return
      end
c-----------------------------------------------------------------------

      subroutine pot_nn_ewald_old(cent,znuc,iwctype,ncent,pecent)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'force.h'
      include 'ewald.h'
      include 'pseudo.h'

      common /dim/ ndim
      common /periodic/ rlatt(3,3),glatt(3,3),rlatt_sim(3,3),glatt_sim(3,3)
     &,rlatt_inv(3,3),rlatt_sim_inv(3,3),glatt_inv(3,3)
     &,cutr,cutr_sim,cutg,cutg_sim,cutg_big,cutg_sim_big
     &,igvec(3,NGVEC_BIGX),gvec(3,NGVEC_BIGX),gnorm(NGNORM_BIGX),igmult(NGNORM_BIGX)
     &,igvec_sim(3,NGVEC_SIM_BIGX),gvec_sim(3,NGVEC_SIM_BIGX),gnorm_sim(NGNORM_SIM_BIGX),igmult_sim(NGNORM_SIM_BIGX)
     &,rkvec_shift(3),kvec(3,MKPTS),rkvec(3,MKPTS),rknorm(MKPTS)
     &,k_inv(MKPTS),nband(MKPTS),ireal_imag(MORB)
     &,znuc_sum,znuc2_sum,vcell,vcell_sim
     &,ngnorm,ngvec,ngnorm_sim,ngvec_sim,ngnorm_orb,ngvec_orb,nkvec
     &,ngnorm_big,ngvec_big,ngnorm_sim_big,ngvec_sim_big
     &,ng1d(3),ng1d_sim(3),npoly,ncoef,np,isrange
      common /ewald/ b_coul(NCOEFX),y_coul(NGNORMX)
     &,b_coul_sim(NCOEFX),y_coul_sim(NGNORM_SIMX)
     &,b_psp(NCOEFX,MCTYPE),y_psp(NGNORMX,MCTYPE)
     &,b_jas(NCOEFX),y_jas(NGNORM_SIMX)
     &,cos_n_sum(NGVECX),sin_n_sum(NGVECX),cos_e_sum(NGVECX),sin_e_sum(NGVECX)
     &,cos_e_sum_sim(NGVEC_SIMX),sin_e_sum_sim(NGVEC_SIMX)
     &,cos_p_sum(NGVECX),sin_p_sum(NGVECX)

      dimension znuc(MCTYPE),cent(3,MCENT),iwctype(MCENT)
      dimension r(3)

      lowest_pow=-1
c     c0=(b_coul(2)-np*b_coul(1))/2
      c0=b_coul(2)/2
      vs=c0*znuc2_sum
      vl=0
      do 20 i=1,ncent
        do 20 j=1,i
          zprod=znuc(iwctype(i))*znuc(iwctype(j))
          do 10 k=1,ndim
   10       r(k)=cent(k,j)-cent(k,i)
          call find_image3(r,rnorm,rlatt,rlatt_inv)
          if(i.ne.j) then
            vs=vs+zprod*vsrange4(rnorm,cutr,lowest_pow,ncoef,np,b_coul,junk,junk)
          endif
          vlr=vlrange_old(r,gvec,ngnorm,igmult,y_coul)
          if(i.eq.j) vlr=0.5d0*vlr
   20     vl=vl+zprod*vlr
      pecent=vs+vl
      vs=vs*2/ncent
      vl=vl*2/ncent
      write(6,'(''v_nn,vs,vl,vs1,vl1='',9f12.8)') pecent*2/ncent,vs,vl,znuc2_sum*c0*2/ncent
      pecent=pecent*vcell_sim/vcell

      return
      end
c-----------------------------------------------------------------------

      subroutine pot_nn_ewald(cent,znuc,iwctype,ncent,pecent)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'force.h'
      include 'ewald.h'
      include 'pseudo.h'

      common /dim/ ndim
      common /periodic/ rlatt(3,3),glatt(3,3),rlatt_sim(3,3),glatt_sim(3,3)
     &,rlatt_inv(3,3),rlatt_sim_inv(3,3),glatt_inv(3,3)
     &,cutr,cutr_sim,cutg,cutg_sim,cutg_big,cutg_sim_big
     &,igvec(3,NGVEC_BIGX),gvec(3,NGVEC_BIGX),gnorm(NGNORM_BIGX),igmult(NGNORM_BIGX)
     &,igvec_sim(3,NGVEC_SIM_BIGX),gvec_sim(3,NGVEC_SIM_BIGX),gnorm_sim(NGNORM_SIM_BIGX),igmult_sim(NGNORM_SIM_BIGX)
     &,rkvec_shift(3),kvec(3,MKPTS),rkvec(3,MKPTS),rknorm(MKPTS)
     &,k_inv(MKPTS),nband(MKPTS),ireal_imag(MORB)
     &,znuc_sum,znuc2_sum,vcell,vcell_sim
     &,ngnorm,ngvec,ngnorm_sim,ngvec_sim,ngnorm_orb,ngvec_orb,nkvec
     &,ngnorm_big,ngvec_big,ngnorm_sim_big,ngvec_sim_big
     &,ng1d(3),ng1d_sim(3),npoly,ncoef,np,isrange
      common /ewald/ b_coul(NCOEFX),y_coul(NGNORMX)
     &,b_coul_sim(NCOEFX),y_coul_sim(NGNORM_SIMX)
     &,b_psp(NCOEFX,MCTYPE),y_psp(NGNORMX,MCTYPE)
     &,b_jas(NCOEFX),y_jas(NGNORM_SIMX)
     &,cos_n_sum(NGVECX),sin_n_sum(NGVECX),cos_e_sum(NGVECX),sin_e_sum(NGVECX)
     &,cos_e_sum_sim(NGVEC_SIMX),sin_e_sum_sim(NGVEC_SIMX)
     &,cos_p_sum(NGVECX),sin_p_sum(NGVECX)

      dimension znuc(MCTYPE),cent(3,MCENT),iwctype(MCENT)
      dimension r(3)

c short-range sum
      shortest_dist=DBLMAX
      lowest_pow=-1
c     c0=(b_coul(2)-np*b_coul(1))/2
      c0=b_coul(2)/2
      vs=c0*znuc2_sum
      do 40 i=1,ncent
        do 40 j=1,i-1
          zprod=znuc(iwctype(i))*znuc(iwctype(j))
          do 10 k=1,ndim
   10       r(k)=cent(k,j)-cent(k,i)
          call find_image3(r,rnorm,rlatt,rlatt_inv)
          shortest_dist=min(shortest_dist,rnorm)
   40     vs=vs+zprod*vsrange4(rnorm,cutr,lowest_pow,ncoef,np,b_coul,junk,junk)

c long-range sum
c     call cossin_old2(glatt,igvec,ngvec,cent,ncent,ng1d,cos_g,sin_g)
      call cossin_n(znuc,iwctype,glatt,igvec,ngvec,cent,ncent,ng1d,cos_n_sum,sin_n_sum)

c     vl=vlrange_nn_old2(ncent,znuc,iwctype,ngnorm,igmult,cos_g,sin_g,y_coul)
c     r(1)=1.d-20
c     r(2)=1.d-20
c     r(3)=1.d-20
c     vl_tmp1=vlrange_old(r,gvec,ngnorm,igmult,y_coul)
c     r(1)=cent(1,2)
c     r(2)=cent(2,2)
c     r(3)=cent(3,2)
c     vl_tmp2=vlrange_old(r,gvec,ngnorm,igmult,y_coul)
c     vl_tmp=vl_tmp1+vl_tmp2

      vl=vlrange(ngnorm,igmult,cos_n_sum,cos_n_sum,sin_n_sum,sin_n_sum,y_coul)
c     write(6,'(''vl_tmp,vl'',4f9.6)') vl_tmp1,vl_tmp2,vl_tmp,vl
c     vl=vl+0.5d0*y_coul(1)*znuc_sum**2

      pecent=vs+vl
      vs=vs*2/ncent
      vl=vl*2/ncent
      if(ncent.ge.2) write(6,'(''shortest dist. between nuclei='',f12.8)') shortest_dist
      write(6,'(''v_nn,vs,vl,vs1,vl1='',9f12.8)') pecent*2/ncent,vs,vl,znuc2_sum*c0*2/ncent,y_coul(1)*znuc_sum**2/ncent
      pecent=pecent*vcell_sim/vcell

      return
      end
c-----------------------------------------------------------------------

      subroutine pot_en_ewald(x,pe_en)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'force.h'
      include 'ewald.h'
      include 'pseudo.h'

      common /dim/ ndim
      common /atom/ znuc(MCTYPE),cent(3,MCENT),pecent
     &,iwctype(MCENT),nctype,ncent
      common /periodic/ rlatt(3,3),glatt(3,3),rlatt_sim(3,3),glatt_sim(3,3)
     &,rlatt_inv(3,3),rlatt_sim_inv(3,3),glatt_inv(3,3)
     &,cutr,cutr_sim,cutg,cutg_sim,cutg_big,cutg_sim_big
     &,igvec(3,NGVEC_BIGX),gvec(3,NGVEC_BIGX),gnorm(NGNORM_BIGX),igmult(NGNORM_BIGX)
     &,igvec_sim(3,NGVEC_SIM_BIGX),gvec_sim(3,NGVEC_SIM_BIGX),gnorm_sim(NGNORM_SIM_BIGX),igmult_sim(NGNORM_SIM_BIGX)
     &,rkvec_shift(3),kvec(3,MKPTS),rkvec(3,MKPTS),rknorm(MKPTS)
     &,k_inv(MKPTS),nband(MKPTS),ireal_imag(MORB)
     &,znuc_sum,znuc2_sum,vcell,vcell_sim
     &,ngnorm,ngvec,ngnorm_sim,ngvec_sim,ngnorm_orb,ngvec_orb,nkvec
     &,ngnorm_big,ngvec_big,ngnorm_sim_big,ngvec_sim_big
     &,ng1d(3),ng1d_sim(3),npoly,ncoef,np,isrange
      common /ewald/ b_coul(NCOEFX),y_coul(NGNORMX)
     &,b_coul_sim(NCOEFX),y_coul_sim(NGNORM_SIMX)
     &,b_psp(NCOEFX,MCTYPE),y_psp(NGNORMX,MCTYPE)
     &,b_jas(NCOEFX),y_jas(NGNORM_SIMX)
     &,cos_n_sum(NGVECX),sin_n_sum(NGVECX),cos_e_sum(NGVECX),sin_e_sum(NGVECX)
     &,cos_e_sum_sim(NGVEC_SIMX),sin_e_sum_sim(NGVEC_SIMX)
     &,cos_p_sum(NGVECX),sin_p_sum(NGVECX)

      common /const/ pi,hb,etrial,delta,deltai,fbias,nelec,imetro,ipr
c     common /config/ xold(3,MELEC),xnew(3,MELEC),vold(3,MELEC)
c    &,vnew(3,MELEC),psi2o(MFORCE),psi2n(MFORCE),eold(MFORCE),enew(MFORCE)
c    &,peo,pen,tjfn,tjfo,psido,psijo
c    &,rmino(MELEC),rminn(MELEC),rvmino(3,MELEC),rvminn(3,MELEC)
c    &,rminon(MELEC),rminno(MELEC),rvminon(3,MELEC),rvminno(3,MELEC)
c    &,nearesto(MELEC),nearestn(MELEC),delttn(MELEC)
      common /pseudo/ vps(MELEC,MCENT,MPS_L),vpso(MELEC,MCENT,MPS_L,MFORCE)
     &,npotd(MCTYPE),lpotp1(MCTYPE),nloc
      common /distance/ rshift(3,MELEC,MCENT),rvec_en(3,MELEC,MCENT),r_en(MELEC,MCENT),rvec_ee(3,MMAT_DIM2),r_ee(MMAT_DIM2)

      dimension x(3,*)

c short-range sum
c Warning: I need to call the appropriate vsrange
      vs=0
      do 40 i=1,ncent
        ict=iwctype(i)
        do 40 j=1,nelec
          do 10 k=1,ndim
   10       rvec_en(k,j,i)=x(k,j)-cent(k,i)
c         call find_image3(rvec_en(1,j,i),r_en(j,i),rlatt,rlatt_inv)
          call find_image4(rshift(1,j,i),rvec_en(1,j,i),r_en(j,i),rlatt,rlatt_inv)
          if(nloc.eq.0) then
            lowest_pow=-1
            vs=vs-znuc(iwctype(i))*vsrange4(r_en(j,i),cutr,lowest_pow,ncoef,np,b_coul,junk,junk)
           else
            lowest_pow=0
c           vs=vs+vsrange4(r_en(j,i),cutr,lowest_pow,ncoef,np,b_psp(1,ict))
            if(isrange.eq.0) vs=vs+vsrange(r_en(j,i),cutr,lowest_pow,ncoef,np,b_psp(1,ict))
            if(isrange.eq.1) vs=vs+vsrange1(r_en(j,i),cutr,lowest_pow,ncoef,np,b_psp(1,ict),ict,lpotp1(ict))
            if(isrange.eq.4) vs=vs+vsrange4(r_en(j,i),cutr,lowest_pow,ncoef,np,b_psp(1,ict),ict,lpotp1(ict))
          endif
   40 continue

c long-range sum
c     call cossin_e(glatt,igvec,ngvec,xold,nelec,ng1d,cos_e_sum,sin_e_sum)
      call cossin_e(glatt,igvec,ngvec,x,nelec,ng1d,cos_e_sum,sin_e_sum)

      if(nloc.eq.0) then
        vl=-2*vlrange(ngnorm,igmult,cos_n_sum,cos_e_sum,sin_n_sum,sin_e_sum,y_coul)
c       vl=vl-y_coul(1)*znuc_sum*nelec
       else
        call cossin_p(y_psp,iwctype,glatt,igvec,ngnorm,igmult,cent,ncent,ng1d,cos_p_sum,sin_p_sum)
        vl=+2*vlrange_p(ngnorm,igmult,cos_p_sum,cos_e_sum,sin_p_sum,sin_e_sum)
c       vl=vl+y_psp(1,iwctype(i))*znuc_sum*nelec
      endif

      pe_en=vs+vl
      vs=vs/nelec
      vl=vl/nelec
      if(ipr.ge.2) then
        if(nloc.eq.0) write(6,'(''v_en,vs,vl,vl1='',9f12.8)') pe_en/nelec,vs,vl,-y_coul(1)*znuc_sum
        if(nloc.ne.0) write(6,'(''v_en,vs,vl,vl1='',9f12.8)') pe_en/nelec,vs,vl,y_psp(1,1)*znuc_sum
      endif

      return
      end
c-----------------------------------------------------------------------

      subroutine pot_ee_ewald(x,pe_ee)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'force.h'
      include 'ewald.h'
      include 'pseudo.h'

      common /dim/ ndim
      common /periodic/ rlatt(3,3),glatt(3,3),rlatt_sim(3,3),glatt_sim(3,3)
     &,rlatt_inv(3,3),rlatt_sim_inv(3,3),glatt_inv(3,3)
     &,cutr,cutr_sim,cutg,cutg_sim,cutg_big,cutg_sim_big
     &,igvec(3,NGVEC_BIGX),gvec(3,NGVEC_BIGX),gnorm(NGNORM_BIGX),igmult(NGNORM_BIGX)
     &,igvec_sim(3,NGVEC_SIM_BIGX),gvec_sim(3,NGVEC_SIM_BIGX),gnorm_sim(NGNORM_SIM_BIGX),igmult_sim(NGNORM_SIM_BIGX)
     &,rkvec_shift(3),kvec(3,MKPTS),rkvec(3,MKPTS),rknorm(MKPTS)
     &,k_inv(MKPTS),nband(MKPTS),ireal_imag(MORB)
     &,znuc_sum,znuc2_sum,vcell,vcell_sim
     &,ngnorm,ngvec,ngnorm_sim,ngvec_sim,ngnorm_orb,ngvec_orb,nkvec
     &,ngnorm_big,ngvec_big,ngnorm_sim_big,ngvec_sim_big
     &,ng1d(3),ng1d_sim(3),npoly,ncoef,np,isrange
      common /ewald/ b_coul(NCOEFX),y_coul(NGNORMX)
     &,b_coul_sim(NCOEFX),y_coul_sim(NGNORM_SIMX)
     &,b_psp(NCOEFX,MCTYPE),y_psp(NGNORMX,MCTYPE)
     &,b_jas(NCOEFX),y_jas(NGNORM_SIMX)
     &,cos_n_sum(NGVECX),sin_n_sum(NGVECX),cos_e_sum(NGVECX),sin_e_sum(NGVECX)
     &,cos_e_sum_sim(NGVEC_SIMX),sin_e_sum_sim(NGVEC_SIMX)
     &,cos_p_sum(NGVECX),sin_p_sum(NGVECX)

      common /const/ pi,hb,etrial,delta,deltai,fbias,nelec,imetro,ipr
c     common /config/ xold(3,MELEC),xnew(3,MELEC),vold(3,MELEC)
c    &,vnew(3,MELEC),psi2o(MFORCE),psi2n(MFORCE),eold(MFORCE),enew(MFORCE)
c    &,peo,pen,tjfn,tjfo,psido,psijo
c    &,rmino(MELEC),rminn(MELEC),rvmino(3,MELEC),rvminn(3,MELEC)
c    &,rminon(MELEC),rminno(MELEC),rvminon(3,MELEC),rvminno(3,MELEC)
c    &,nearesto(MELEC),nearestn(MELEC),delttn(MELEC)
      common /distance/ rshift(3,MELEC,MCENT),rvec_en(3,MELEC,MCENT),r_en(MELEC,MCENT),rvec_ee(3,MMAT_DIM2),r_ee(MMAT_DIM2)

      dimension x(3,*)

c short-range sum
      lowest_pow=-1
c     c0=(b_coul_sim(2)-np*b_coul_sim(1))/2
      c0=b_coul_sim(2)/2
      vs=c0*nelec
      ij=0
      do 40 i=1,nelec
        do 40 j=1,i-1
          ij=ij+1
          do 10 k=1,ndim
   10       rvec_ee(k,ij)=x(k,i)-x(k,j)
          call find_image3(rvec_ee(1,ij),r_ee(ij),rlatt_sim,rlatt_sim_inv)
   40     vs=vs+vsrange4(r_ee(ij),cutr_sim,lowest_pow,ncoef,np,b_coul_sim,junk,junk)

c long-range sum
c     call cossin_old2(glatt_sim,igvec_sim,ngvec_sim,xold,nelec,ng1d_sim,cos_g,sin_g)
c     call cossin_e(glatt_sim,igvec_sim,ngvec_sim,xold,nelec,ng1d_sim,cos_e_sum_sim,sin_e_sum_sim)
      call cossin_e(glatt_sim,igvec_sim,ngvec_sim,x,nelec,ng1d_sim,cos_e_sum_sim,sin_e_sum_sim)

c     vl=vlrange_ee_old2(nelec,ngnorm_sim,igmult_sim,cos_g,sin_g,y_coul_sim)
      vl=vlrange(ngnorm_sim,igmult_sim,cos_e_sum_sim,cos_e_sum_sim,sin_e_sum_sim,sin_e_sum_sim,y_coul_sim)
c     vl=vl+0.5d0*y_coul_sim(1)*nelec**2

      pe_ee=vs+vl
      vs=vs*2/nelec
      vl=vl*2/nelec
      if(ipr.ge.2) write(6,'(''v_ee,vs,vl,vs1,vl1='',9f12.8)') pe_ee*2/nelec,vs,vl,c0*2,y_coul_sim(1)*nelec

      return
      end
c-----------------------------------------------------------------------

      subroutine cossin_old2(glatt,igvec,ngvec,r,nr,ng1d,cos_g,sin_g)
c Written by Cyrus Umrigar

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      common /dim/ ndim
      dimension glatt(3,3),igvec(3,*),r(3,*),cos_g(MELEC,*),sin_g(MELEC,*)
     &,ng1d(3)
      dimension cos_gr(-NG1DX:NG1DX,3),sin_gr(-NG1DX:NG1DX,3)

c Calculate cosines and sines for all positions and reciprocal lattice vectors
      do 30 ir=1,nr
      do 20 i=1,ndim
        dot=0
        do 10 k=1,ndim
   10     dot=dot+glatt(k,i)*r(k,ir)
        cos_gr(1,i)=cos(dot)
        sin_gr(1,i)=sin(dot)
        cos_gr(-1,i)=cos_gr(1,i)
        sin_gr(-1,i)=-sin_gr(1,i)
        cos_gr(0,i)=1.d0
        sin_gr(0,i)=0.d0
        do 20 n=2,ng1d(i)
          cos_gr(n,i)=cos_gr(n-1,i)*cos_gr(1,i)-sin_gr(n-1,i)*sin_gr(1,i)
          sin_gr(n,i)=sin_gr(n-1,i)*cos_gr(1,i)+cos_gr(n-1,i)*sin_gr(1,i)
          cos_gr(-n,i)=cos_gr(n,i)
   20     sin_gr(-n,i)=-sin_gr(n,i)

      cos_g(ir,1)=1.d0
      sin_g(ir,1)=0.d0
      do 30 i=2,ngvec
        cos_tmp=cos_gr(igvec(1,i),1)*cos_gr(igvec(2,i),2)
     &         -sin_gr(igvec(1,i),1)*sin_gr(igvec(2,i),2)
        sin_tmp=sin_gr(igvec(1,i),1)*cos_gr(igvec(2,i),2)
     &         +cos_gr(igvec(1,i),1)*sin_gr(igvec(2,i),2)
        cos_g(ir,i)=cos_tmp*cos_gr(igvec(3,i),3)
     &             -sin_tmp*sin_gr(igvec(3,i),3)
   30   sin_g(ir,i)=sin_tmp*cos_gr(igvec(3,i),3)
     &             +cos_tmp*sin_gr(igvec(3,i),3)

      return
      end
c-----------------------------------------------------------------------

      subroutine cossin_psi(glatt,gnorm,gvec,igvec,ngvec,r,nr,ng1d,cos_g,sin_g
     &,dcos_g,dsin_g,ddcos_g,ddsin_g,g_shift,iflag)
c Written by Cyrus Umrigar
c iflag = 0 Calculate cos(gr) and sin(gr) and first 2 derivs at electron positions.
c       = 1 Calculate cos(kr) and sin(kr) and first 2 derivs at electron positions.
c Needed for orbitals and their Laplacian.
c Presently using cossin_psi_g and cossin_psi_k instead.

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      common /dim/ ndim
      dimension glatt(3,3),gnorm(*),gvec(3,*),igvec(3,*),r(3,*),ng1d(3)
     &,cos_g(MELEC,*),sin_g(MELEC,*)
     &,dcos_g(3,MELEC,*),dsin_g(3,MELEC,*)
     &,ddcos_g(MELEC,*),ddsin_g(MELEC,*),g_shift(*)
      dimension cos_gr(-NG1DX:NG1DX,3),sin_gr(-NG1DX:NG1DX,3)

c Calculate cosines and sines for recip. lattice vectors along axes first.
      do 30 ir=1,nr
      do 20 i=1,ndim
        dot=0
        do 10 k=1,ndim
   10     dot=dot+glatt(k,i)*r(k,ir)
        cos_gr(1,i)=cos(dot)
        sin_gr(1,i)=sin(dot)
        cos_gr(-1,i)=cos_gr(1,i)
        sin_gr(-1,i)=-sin_gr(1,i)
        cos_gr(0,i)=1.d0
        sin_gr(0,i)=0.d0
        do 20 n=2,ng1d(i)
          cos_gr(n,i)=cos_gr(n-1,i)*cos_gr(1,i)-sin_gr(n-1,i)*sin_gr(1,i)
          sin_gr(n,i)=sin_gr(n-1,i)*cos_gr(1,i)+cos_gr(n-1,i)*sin_gr(1,i)
          cos_gr(-n,i)=cos_gr(n,i)
   20     sin_gr(-n,i)=-sin_gr(n,i)

c If the calculation is for g-vectors then no shift; if for k-vectors there could be one.
      if(iflag.eq.0) then
        cos_tmp0=1.d0
        sin_tmp0=0.d0
       elseif(iflag.eq.1) then
        dot=0
        do 25 k=1,ndim
   25     dot=dot+g_shift(k)*r(k,ir)
        cos_tmp0=cos(dot)
        sin_tmp0=sin(dot)
       else
        stop 'iflag must be 0 or 1 in cossin_psi'
      endif

      do 30 i=1,ngvec
        cos_tmp1=cos_tmp0*cos_gr(igvec(1,i),1)
     &          -sin_tmp0*sin_gr(igvec(1,i),1)
        sin_tmp1=sin_tmp0*cos_gr(igvec(1,i),1)
     &          +cos_tmp0*sin_gr(igvec(1,i),1)
        cos_tmp2=cos_tmp1*cos_gr(igvec(2,i),2)
     &          -sin_tmp1*sin_gr(igvec(2,i),2)
        sin_tmp2=sin_tmp1*cos_gr(igvec(2,i),2)
     &          +cos_tmp1*sin_gr(igvec(2,i),2)
        cos_g(ir,i)=cos_tmp2*cos_gr(igvec(3,i),3)
     &             -sin_tmp2*sin_gr(igvec(3,i),3)
        sin_g(ir,i)=sin_tmp2*cos_gr(igvec(3,i),3)
     &             +cos_tmp2*sin_gr(igvec(3,i),3)
        do 27 k=1,ndim
          dcos_g(k,ir,i)=-gvec(k,i)*sin_g(ir,i)
   27     dsin_g(k,ir,i)= gvec(k,i)*cos_g(ir,i)
c       if(i.lt.5) write(6,'(''ir,i,gnorm(i),cos_g(ir,i),sin_g(ir,i),dcos_g(k,ir,i),dsin_g(k,ir,i)'',2i5,9d12.4)')
c    & ir,i,gnorm(i),cos_g(ir,i),sin_g(ir,i),(dcos_g(k,ir,i),dsin_g(k,ir,i),k=1,ndim)
        ddcos_g(ir,i)=-gnorm(i)*gnorm(i)*cos_g(ir,i)
   30   ddsin_g(ir,i)=-gnorm(i)*gnorm(i)*sin_g(ir,i)

      return
      end
c-----------------------------------------------------------------------

c     subroutine cossin_psi_g(glatt,gnorm,igmult,ngnorm,gvec,igvec,ngvec,r,nr,ng1d,cos_g,sin_g
      subroutine cossin_psi_g(glatt,gnorm,igmult,ngnorm,gvec,igvec,ngvec,r,ng1d,cos_g,sin_g
     &,dcos_g,dsin_g,ddcos_g,ddsin_g,g_shift)
c Written by Cyrus Umrigar
c Calculate cos(gr) and sin(gr) and first 2 derivs at electron position r.
c Needed for orbitals and their Laplacian.

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      common /dim/ ndim
c     dimension glatt(3,3),gnorm(*),igmult(*),gvec(3,*),igvec(3,*),r(3,*),ng1d(3)
c    &,cos_g(MELEC,*),sin_g(MELEC,*)
c    &,dcos_g(3,MELEC,*),dsin_g(3,MELEC,*)
c    &,ddcos_g(MELEC,*),ddsin_g(MELEC,*),g_shift(*)
      dimension glatt(3,3),gnorm(*),igmult(*),gvec(3,*),igvec(3,*),r(3),ng1d(3)
     &,cos_g(*),sin_g(*)
     &,dcos_g(3,*),dsin_g(3,*)
     &,ddcos_g(*),ddsin_g(*),g_shift(*)
      dimension cos_gr(-NG1DX:NG1DX,3),sin_gr(-NG1DX:NG1DX,3)

c Calculate cosines and sines for recip. lattice vectors along axes first.
c     do 30 ir=1,nr
      do 20 i=1,ndim
        dot=0
        do 10 k=1,ndim
   10     dot=dot+glatt(k,i)*r(k)
        cos_gr(1,i)=cos(dot)
        sin_gr(1,i)=sin(dot)
        cos_gr(-1,i)=cos_gr(1,i)
        sin_gr(-1,i)=-sin_gr(1,i)
        cos_gr(0,i)=1.d0
        sin_gr(0,i)=0.d0
        do 20 n=2,ng1d(i)
          cos_gr(n,i)=cos_gr(n-1,i)*cos_gr(1,i)-sin_gr(n-1,i)*sin_gr(1,i)
          sin_gr(n,i)=sin_gr(n-1,i)*cos_gr(1,i)+cos_gr(n-1,i)*sin_gr(1,i)
          cos_gr(-n,i)=cos_gr(n,i)
   20     sin_gr(-n,i)=-sin_gr(n,i)

c If the calculation is for g-vectors then no shift; if for k-vectors there could be one.
c     if(iflag.eq.0) then
c       cos_tmp0=1.d0
c       sin_tmp0=0.d0
c      elseif(iflag.eq.1) then
c       dot=0
c       do 25 k=1,ndim
c  25     dot=dot+g_shift(k)*r(k,ir)
c       cos_tmp0=cos(dot)
c       sin_tmp0=sin(dot)
c      else
c       stop 'iflag must be 0 or 1 in cossin_psi'
c     endif

c     cos_g(1)=1.d0
c     sin_g(1)=0.d0
      i=0
      do 30 in=1,ngnorm
        do 30 im=1,igmult(in)
        i=i+1
        cos_tmp=cos_gr(igvec(1,i),1)*cos_gr(igvec(2,i),2)
     &         -sin_gr(igvec(1,i),1)*sin_gr(igvec(2,i),2)
        sin_tmp=sin_gr(igvec(1,i),1)*cos_gr(igvec(2,i),2)
     &         +cos_gr(igvec(1,i),1)*sin_gr(igvec(2,i),2)
        cos_g(i)=cos_tmp*cos_gr(igvec(3,i),3)
     &             -sin_tmp*sin_gr(igvec(3,i),3)
        sin_g(i)=sin_tmp*cos_gr(igvec(3,i),3)
     &             +cos_tmp*sin_gr(igvec(3,i),3)

c     do 30 i=1,ngvec
c       cos_tmp1=cos_tmp0*cos_gr(igvec(1,i),1)
c    &          -sin_tmp0*sin_gr(igvec(1,i),1)
c       sin_tmp1=sin_tmp0*cos_gr(igvec(1,i),1)
c    &          +cos_tmp0*sin_gr(igvec(1,i),1)
c       cos_tmp2=cos_tmp1*cos_gr(igvec(2,i),2)
c    &          -sin_tmp1*sin_gr(igvec(2,i),2)
c       sin_tmp2=sin_tmp1*cos_gr(igvec(2,i),2)
c    &          +cos_tmp1*sin_gr(igvec(2,i),2)
c       cos_g(i)=cos_tmp2*cos_gr(igvec(3,i),3)
c    &             -sin_tmp2*sin_gr(igvec(3,i),3)
c       sin_g(i)=sin_tmp2*cos_gr(igvec(3,i),3)
c    &             +cos_tmp2*sin_gr(igvec(3,i),3)
        do 27 k=1,ndim
          dcos_g(k,i)=-gvec(k,i)*sin_g(i)
   27     dsin_g(k,i)= gvec(k,i)*cos_g(i)
c       if(i.lt.5) write(6,'(''i,gnorm(in),cos_g(i),sin_g(i),dcos_g(k,i),dsin_g(k,i)'',2i5,9d12.4)')
c    & i,gnorm(in),cos_g(i),sin_g(i),(dcos_g(k,i),dsin_g(k,i),k=1,ndim)
        ddcos_g(i)=-gnorm(in)*gnorm(in)*cos_g(i)
   30   ddsin_g(i)=-gnorm(in)*gnorm(in)*sin_g(i)

      return
      end
c-----------------------------------------------------------------------

c     subroutine cossin_psi_k(glatt,gnorm,gvec,igvec,ngvec,r,nr,ng1d,cos_g,sin_g
      subroutine cossin_psi_k(glatt,gnorm,gvec,igvec,ngvec,r,ng1d,cos_g,sin_g
     &,dcos_g,dsin_g,ddcos_g,ddsin_g,g_shift)
c Written by Cyrus Umrigar
c Needed for orbitals and their Laplacian.
c For the k-vectors do it straightforwardly since there are few of them

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      common /dim/ ndim
c     dimension glatt(3,3),gnorm(*),gvec(3,*),igvec(3,*),r(3,*),ng1d(3)
c    &,cos_g(MELEC,*),sin_g(MELEC,*)
c    &,dcos_g(3,MELEC,*),dsin_g(3,MELEC,*)
c    &,ddcos_g(MELEC,*),ddsin_g(MELEC,*),g_shift(*)
      dimension glatt(3,3),gnorm(*),gvec(3,*),igvec(3,*),r(3),ng1d(3)
     &,cos_g(*),sin_g(*)
     &,dcos_g(3,*),dsin_g(3,*)
     &,ddcos_g(*),ddsin_g(*),g_shift(*)

c     do 30 ir=1,nr
      do 30 i=1,ngvec
        dot=0
        do 10 k=1,ndim
   10     dot=dot+gvec(k,i)*r(k)
        cos_g(i)=cos(dot)
        sin_g(i)=sin(dot)
        do 27 k=1,ndim
          dcos_g(k,i)=-gvec(k,i)*sin_g(i)
   27     dsin_g(k,i)= gvec(k,i)*cos_g(i)
c       if(i.lt.5) write(6,'(''i,gnorm(i),cos_g(i),sin_g(i),dcos_g(k,i),dsin_g(k,i)'',2i5,9d12.4)')
c    & i,gnorm(i),cos_g(i),sin_g(i),(dcos_g(k,i),dsin_g(k,i),k=1,ndim)
        ddcos_g(i)=-gnorm(i)*gnorm(i)*cos_g(i)
   30   ddsin_g(i)=-gnorm(i)*gnorm(i)*sin_g(i)

      return
      end

c-----------------------------------------------------------------------
c The only diff. between cossin_n, cossin_p and cossin_e is whether the
c nuclear charge, pseudopotential or electronic charge is used, so they
c could be merged, but I did not do that to get a small gain in efficiency.
c-----------------------------------------------------------------------

      subroutine cossin_n(znuc,iwctype,glatt,igvec,ngvec,r,nr,ng1d,cos_sum,sin_sum)
c Written by Cyrus Umrigar
c Calculate cos_sum and sin_sum for nuclei

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      common /dim/ ndim
      dimension znuc(*),iwctype(*),glatt(3,3),igvec(3,*),r(3,*),ng1d(3),cos_sum(*),sin_sum(*)
      dimension cos_gr(-NG1DX:NG1DX,3,MCENT),sin_gr(-NG1DX:NG1DX,3,MCENT)

c Calculate cosines and sines for all positions and reciprocal lattice vectors
      do 20 ir=1,nr
        do 20 i=1,ndim
          dot=0
          do 10 k=1,ndim
   10       dot=dot+glatt(k,i)*r(k,ir)
          cos_gr(1,i,ir)=cos(dot)
          sin_gr(1,i,ir)=sin(dot)
          cos_gr(-1,i,ir)=cos_gr(1,i,ir)
          sin_gr(-1,i,ir)=-sin_gr(1,i,ir)
          cos_gr(0,i,ir)=1.d0
          sin_gr(0,i,ir)=0.d0
          do 20 n=2,ng1d(i)
            cos_gr(n,i,ir)=cos_gr(n-1,i,ir)*cos_gr(1,i,ir)-sin_gr(n-1,i,ir)*sin_gr(1,i,ir)
            sin_gr(n,i,ir)=sin_gr(n-1,i,ir)*cos_gr(1,i,ir)+cos_gr(n-1,i,ir)*sin_gr(1,i,ir)
            cos_gr(-n,i,ir)=cos_gr(n,i,ir)
   20       sin_gr(-n,i,ir)=-sin_gr(n,i,ir)

      do 30 i=1,ngvec
        cos_sum(i)=0
        sin_sum(i)=0
        do 30 ir=1,nr
          cos_tmp=cos_gr(igvec(1,i),1,ir)*cos_gr(igvec(2,i),2,ir)
     &           -sin_gr(igvec(1,i),1,ir)*sin_gr(igvec(2,i),2,ir)
          sin_tmp=sin_gr(igvec(1,i),1,ir)*cos_gr(igvec(2,i),2,ir)
     &           +cos_gr(igvec(1,i),1,ir)*sin_gr(igvec(2,i),2,ir)
          cos_sum(i)=cos_sum(i)+znuc(iwctype(ir))*
     &               (cos_tmp*cos_gr(igvec(3,i),3,ir)
     &               -sin_tmp*sin_gr(igvec(3,i),3,ir))
   30     sin_sum(i)=sin_sum(i)+znuc(iwctype(ir))*
     &               (sin_tmp*cos_gr(igvec(3,i),3,ir)
     &               +cos_tmp*sin_gr(igvec(3,i),3,ir))

      return
      end
c-----------------------------------------------------------------------

      subroutine cossin_p(y_psp,iwctype,glatt,igvec,ngnorm,igmult,r,nr,ng1d,cos_sum,sin_sum)
c Written by Cyrus Umrigar
c Calculate cos_sum and sin_sum for pseudopotentials

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      common /dim/ ndim
      dimension y_psp(NGNORMX,MCTYPE),iwctype(*),glatt(3,3),igvec(3,*),igmult(*),r(3,*)
     &,ng1d(3),cos_sum(*),sin_sum(*)
      dimension cos_gr(-NG1DX:NG1DX,3,MCENT),sin_gr(-NG1DX:NG1DX,3,MCENT)

c Calculate cosines and sines for all positions and reciprocal lattice vectors
      do 20 ir=1,nr
        do 20 i=1,ndim
          dot=0
          do 10 k=1,ndim
   10       dot=dot+glatt(k,i)*r(k,ir)
          cos_gr(1,i,ir)=cos(dot)
          sin_gr(1,i,ir)=sin(dot)
          cos_gr(-1,i,ir)=cos_gr(1,i,ir)
          sin_gr(-1,i,ir)=-sin_gr(1,i,ir)
          cos_gr(0,i,ir)=1.d0
          sin_gr(0,i,ir)=0.d0
          do 20 n=2,ng1d(i)
            cos_gr(n,i,ir)=cos_gr(n-1,i,ir)*cos_gr(1,i,ir)-sin_gr(n-1,i,ir)*sin_gr(1,i,ir)
            sin_gr(n,i,ir)=sin_gr(n-1,i,ir)*cos_gr(1,i,ir)+cos_gr(n-1,i,ir)*sin_gr(1,i,ir)
            cos_gr(-n,i,ir)=cos_gr(n,i,ir)
   20       sin_gr(-n,i,ir)=-sin_gr(n,i,ir)

      i=0
      do 30 k=1,ngnorm
        do 30 im=1,igmult(k)
        i=i+1
        cos_sum(i)=0
        sin_sum(i)=0
        do 30 ir=1,nr
          cos_tmp=cos_gr(igvec(1,i),1,ir)*cos_gr(igvec(2,i),2,ir)
     &           -sin_gr(igvec(1,i),1,ir)*sin_gr(igvec(2,i),2,ir)
          sin_tmp=sin_gr(igvec(1,i),1,ir)*cos_gr(igvec(2,i),2,ir)
     &           +cos_gr(igvec(1,i),1,ir)*sin_gr(igvec(2,i),2,ir)
          cos_sum(i)=cos_sum(i)+y_psp(k,iwctype(ir))*
     &               (cos_tmp*cos_gr(igvec(3,i),3,ir)
     &               -sin_tmp*sin_gr(igvec(3,i),3,ir))
   30     sin_sum(i)=sin_sum(i)+y_psp(k,iwctype(ir))*
     &               (sin_tmp*cos_gr(igvec(3,i),3,ir)
     &               +cos_tmp*sin_gr(igvec(3,i),3,ir))

      return
      end
c-----------------------------------------------------------------------

      subroutine cossin_e(glatt,igvec,ngvec,r,nr,ng1d,cos_sum,sin_sum)
c Written by Cyrus Umrigar
c Calculate cos_sum and sin_sum for electrons

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'ewald.h'

      common /dim/ ndim
      dimension glatt(3,3),igvec(3,*),r(3,*),ng1d(3),cos_sum(*),sin_sum(*)
      dimension cos_gr(-NG1DX:NG1DX,3,MELEC),sin_gr(-NG1DX:NG1DX,3,MELEC)

c Calculate cosines and sines for all positions and reciprocal lattice vectors
      do 20 ir=1,nr
        do 20 i=1,ndim
          dot=0
          do 10 k=1,ndim
   10       dot=dot+glatt(k,i)*r(k,ir)
          cos_gr(1,i,ir)=cos(dot)
          sin_gr(1,i,ir)=sin(dot)
          cos_gr(-1,i,ir)=cos_gr(1,i,ir)
          sin_gr(-1,i,ir)=-sin_gr(1,i,ir)
          cos_gr(0,i,ir)=1.d0
          sin_gr(0,i,ir)=0.d0
          do 20 n=2,ng1d(i)
            cos_gr(n,i,ir)=cos_gr(n-1,i,ir)*cos_gr(1,i,ir)-sin_gr(n-1,i,ir)*sin_gr(1,i,ir)
            sin_gr(n,i,ir)=sin_gr(n-1,i,ir)*cos_gr(1,i,ir)+cos_gr(n-1,i,ir)*sin_gr(1,i,ir)
            cos_gr(-n,i,ir)=cos_gr(n,i,ir)
   20       sin_gr(-n,i,ir)=-sin_gr(n,i,ir)

      do 30 i=1,ngvec
        cos_sum(i)=0
        sin_sum(i)=0
        do 30 ir=1,nr
          cos_tmp=cos_gr(igvec(1,i),1,ir)*cos_gr(igvec(2,i),2,ir)
     &           -sin_gr(igvec(1,i),1,ir)*sin_gr(igvec(2,i),2,ir)
          sin_tmp=sin_gr(igvec(1,i),1,ir)*cos_gr(igvec(2,i),2,ir)
     &           +cos_gr(igvec(1,i),1,ir)*sin_gr(igvec(2,i),2,ir)
          cos_sum(i)=cos_sum(i)+
     &               (cos_tmp*cos_gr(igvec(3,i),3,ir)
     &               -sin_tmp*sin_gr(igvec(3,i),3,ir))
   30     sin_sum(i)=sin_sum(i)+
     &               (sin_tmp*cos_gr(igvec(3,i),3,ir)
     &               +cos_tmp*sin_gr(igvec(3,i),3,ir))

      return
      end
c-----------------------------------------------------------------------
