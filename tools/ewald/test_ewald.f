      program test_ewald

      implicit real*8(a-h,o-z)

      include 'vmc.h'
      include 'force.h'
      include 'ewald.h'
      include 'pseudo.h'

      common /contrl_per/ iperiodic,ibasis
      common /constant/ twopi

      common /dim/ ndim
      common /atom/ znuc(MCTYPE),cent(3,MCENT),pecent
     &,iwctype(MCENT),nctype,ncent
      common /atomtyp/ ncentyp(MCTYPE)
c     common /pseudo_fahy/ potl(MPS_GRID,MCTYPE),ptnlc(MPS_GRID,MCTYPE,MPS_L)
c    &,dradl(MCTYPE),drad(MCTYPE),rcmax(MCTYPE),npotl(MCTYPE)
c    &,nlrad(MCTYPE)
      common /pseudo_tm/ rmax_coul(MCTYPE),rmax_nloc(MCTYPE),arg_ps(MCTYPE),r0_ps(MCTYPE)
     &,vpseudo(MPS_GRID,MCTYPE,MPS_L),d2pot(MPS_GRID,MCTYPE,MPS_L),igrid_ps(MCTYPE),nr_ps(MCTYPE)
      common /pseudo/ vps(MELEC,MCENT,MPS_L),vpso(MELEC,MCENT,MPS_L,MFORCE)
     &,npotd(MCTYPE),lpotp1(MCTYPE),nloc
      common /distance/ rshift(3,MELEC,MCENT),rvec_en(3,MELEC,MCENT),r_en(MELEC,MCENT),rvec_ee(3,MMAT_DIM2),r_ee(MMAT_DIM2)
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

      common /const/ pi,hb,etrial,delta,deltai,fbias,nelec,imetro,ipr
      common /config/ xold(3,MELEC),xnew(3,MELEC),fold(3,MELEC)
     &,fnew(3,MELEC),psi2o(MFORCE),psi2n(MFORCE),eold(MFORCE),enew(MFORCE)
     &,peo,pen,tjfn,tjfo,psido,psijo
     &,rmino(MELEC),rminn(MELEC),rvmino(3,MELEC),rvminn(3,MELEC)
     &,rminon(MELEC),rminno(MELEC),rvminon(3,MELEC),rvminno(3,MELEC)
     &,nearesto(MELEC),nearestn(MELEC),delttn(MELEC)

      common /tempor/ dist_nn
 
      dimension rvec(3),cent_tmp(3)

      pi=4.d0*datan(1.d0)
      twopi=2*pi
      ndim=3
      iperiodic=1

c all-electron or psp
      read(5,*) nloc,ipr
      write(6,'(''nloc='',i2)') nloc

c identify local component.  Note this is overwritten by reading from psp file if nloc=1
      read(5,*) lpotp1(1)
      write(6,'(''lpotp1(1)='',i2)') lpotp1(1)

c f e-e jastrow parameter in J(r) = exp(sspin * f^2 * (1-exp(-r/f))/r)
      read(5,*) f
      write(6,'(''Jastrow f='',f8.4)') f

      read(5,*) alattice
      do 1 i=1,3
        read(5,*) (rlatt(k,i),k=1,3)
        do 1 k=1,3
    1     rlatt(k,i)=rlatt(k,i)*alattice

      write(6,'(/,''Lattice basis vectors'',3(/,3f10.6))')
     & ((rlatt(k,j),k=1,3),j=1,3)

c read the dimensions of the simulation 'cube'
      do 2 i=1,3
        read(5,*) (rlatt_sim(k,i),k=1,3)
        do 2 k=1,3
    2     rlatt_sim(k,i)=rlatt_sim(k,i)*alattice

      write(6,'(/,''Simulation lattice basis vectors'',3(/,3f10.6))')
     & ((rlatt_sim(k,j),k=1,3),j=1,3)

c read k-shift for generating k-vector lattice
      read(5,*) rkvec_shift

c read the dimensions of the simulation 'cube'
c     read(5,*) (lcell(i),i=1,3)
c     write(6,'(/,''Dimension of simulation cell'',3i4)')
c    & (lcell(i),i=1,3)

c     do 150 ilat=1,3
      read (5,*) nctype,ncent,(iwctype(i),i=1,ncent)

      write (6,'(''nctype,ncent ='',t21,2i5)') nctype,ncent
      write (6,'(''iwctype ='',t21,20i3,(20i3))') (iwctype(i),i=1,ncent)

      if(nctype.gt.MCTYPE) stop 'nctype > MCTYPE'
      if(ncent.gt.MCENT) stop 'ncent > MCENT'

      do 4 it=1,nctype
        ncentyp(it)=0
        do 4 ic=1,ncent
    4     if(iwctype(ic).eq.it) ncentyp(it)=ncentyp(it)+1

      read (5,*) (znuc(i),i=1,nctype)
      write(6,'(''znuc='',t21,10f5.1,(10f5.1))') (znuc(i),i=1,nctype)

c     dist_nn=1.d10
c     write (6,'(/,''center positions'')')
      do 10 i=1,ncent
   10   read (5,*) (cent(k,i),k=1,3)
c       do 8 k=1,3
c   8     cent(k,i)=cent(k,i)*alattice
c       write (6,'(''center'',2x,i3,2x,''('',3f8.5,'')'')') i,
c    &  (cent(k,i),k=1,3)
c       do 10 j=1,i-1
c         dist=0
c         do 9 k=1,3
c   9       dist=dist+(cent(k,j)-cent(k,i))**2
c  10     dist_nn=min(dist_nn,sqrt(dist))
c     write(6,'(''dist_nn='',f9.5)') dist_nn

c Convert center positions from primitive lattice vector units to cartesian coordinates
      write(6,'(/,''center positions in primitive lattice vector units and in cartesian coordinates'')')
      dist_nn=1.d10
      do 20 ic=1,ncent
        do 12 k=1,3
   12     cent_tmp(k)=cent(k,ic)
        dist=0
        do 14 k=1,3
          cent(k,ic)=0
          do 14 i=1,3
   14       cent(k,ic)=cent(k,ic)+cent_tmp(i)*rlatt(k,i)
        do 18 jc=1,ic-1
          dist=0
          do 16 k=1,3
   16       dist=dist+(cent(k,jc)-cent(k,ic))**2
   18     dist_nn=min(dist_nn,sqrt(dist))
   20   write(6,'(''center'',i4,1x,''('',3f10.5,'')'',1x,''('',3f9.5,'')'')') ic, (cent_tmp(k),k=1,3),(cent(k,ic),k=1,3)
        write(6,'(''dist_nn='',f10.5)') dist_nn

c Read in electron positions
      read (5,*) nelec
      read (5,*) ((xold(k,i),k=1,3),i=1,nelec)
      do 25 i=1,nelec
        do 25 k=1,3
   25     xold(k,i)=xold(k,i)*alattice


c npoly is the polynomial order for short-range part
      read(5,*) npoly,np,cutg,cutg_sim,cutg_big,cutg_sim_big
      write(6,'(/,''Npoly,np,cutg,cutg_sim,cutg_big,cutg_sim_big'',2i4,9f8.2)')
     & npoly,np,cutg,cutg_sim,cutg_big,cutg_sim_big

      ncoef=npoly+1
      if(ncoef.gt.NCOEFX) stop 'ncoef gt NCOEFX'

      if(nloc.eq.1) then

c read in pseudopotential on shifted exponential grid
c I think for present purpose nctype=1 and so do loop really not needed
      do 31 ict=1,nctype
c Identify which is the local pot. (Usually the one with highest l)
c       lpotp1(ict)=1
        read(2,*) znuc(ict),rpotc
        write(6,'(''znuc,rpotc='',9f7.4)') znuc(ict),rpotc
        read(2,*) nr_ps(ict),arg_ps(ict)
        write(6,'(''nr_ps,arg_ps='',i6,9f7.4)') nr_ps(ict),arg_ps(ict)
        if(nr_ps(ict).gt.MPS_GRID) stop 'nr_ps(ict) gt MPS_GRID'

        do 30 ir=1,nr_ps(ict)
   30     read(2,*) rx,vpseudo(ir,ict,lpotp1(ict))
        rmax_coul(ict)=rx
        r0_ps(ict)=rmax_coul(ict)/(arg_ps(ict)**(nr_ps(ict)-1)-1)
        write(6,'(''r0_ps'',9f10.6)') rmax_coul(ict),rx,r0_ps(ict)
   31 rewind 2

       elseif(nloc.eq.2) then
c       lpotp1(1)=3
        call readps_tm

      endif

      call set_ewald

      write(6,*) 'Done with set_ewald'

c check Madelung constant for CsCl, NaCl, ZnS lattices
c  91 do 150 ilat=1,3
c     read (5,*) nctype,ncent,(iwctype(i),i=1,ncent)

c     write (6,'(''nctype,ncent ='',t21,2i5)') nctype,ncent
c     write (6,'(''iwctype ='',t21,20i3,(20i3))') (iwctype(i),i=1,ncent)

c     if(nctype.gt.MCTYPE) stop 'nctype > MCTYPE'
c     if(ncent.gt.MCENT) stop 'ncent > MCENT'

c     do 95 it=1,nctype
c       ncentyp(it)=0
c       do 95 ic=1,ncent
c  95     if(iwctype(ic).eq.it) ncentyp(it)=ncentyp(it)+1

c     read (5,*) (znuc(i),i=1,nctype)
c     write(6,'(''znuc='',t21,10f5.1,(10f5.1))') (znuc(i),i=1,nctype)

c     dist_nn=1.d10
c     write (6,'(/,''center positions'')')
c     do 110 i=1,ncent
c       read (5,*) (cent(k,i),k=1,3)
c       do 100 k=1,3
c 100     cent(k,i)=cent(k,i)*alattice
c       write (6,'(''center'',2x,i3,2x,''('',3f8.5,'')'')') i,
c    &  (cent(k,i),k=1,3)
c       do 110 j=1,i-1
c         dist=0
c         do 105 k=1,3
c 105       dist=dist+(cent(k,j)-cent(k,i))**2
c 110     dist_nn=min(dist_nn,sqrt(dist))
c     write(6,'(''dist_nn='',f9.5)') dist_nn

c     call pot_nn_ewald_old
c     c_madelung=pecent*dist_nn/(znuc(1)*znuc(2)*ncent/2)
c     write(6,'(''ilat,c_madelung_o='',i1,2f10.6)') ilat,pecent,c_madelung

c     call pot_nn_ewald
c     c_madelung=pecent*dist_nn/(znuc(1)*znuc(2)*ncent/2)
c     write(6,'(''ilat,c_madelung='',i1,2f10.6)') ilat,pecent,c_madelung

ccCheck e-e interaction
c     dist_ee=1.d10
c     do 100 i=1,nelec
c       do 100 j=1,i-1
c         dist=0
c         do 95 k=1,3
c  95       dist=dist+(xold(k,j)-xold(k,i))**2
c 100     dist_ee=min(dist_ee,sqrt(dist))
c     write(6,'(''dist_ee='',f9.5)') dist_ee

c  91 call pot_ee_ewald(xold,pe_ee)
c     c_madelung=pe_ee*dist_nn*2/nelec
c     write(6,'(''pe_ee,c_madelung='',2f10.6)') pe_ee,c_madelung

c     dist_en=1.d10
c     do 110 i=1,ncent
c       do 110 j=1,nelec
c         dist=0
c         do 105 k=1,3
c 105       dist=dist+(xold(k,j)-cent(k,i))**2
c 110     dist_en=min(dist_en,sqrt(dist))
c     write(6,'(''dist_en='',f9.5)') dist_en

ccNote pot_en_ewald must be called after pot_nn_ewald and pot_ee_ewald
ccbecause they calculate cos_n_sum, sin_n_sum, cos_e_sum, sin_e_sum.
ccThe multiplication by cell volume ratios is now done in pot_nn_ewald
c     call pot_en_ewald(xold,pe_en)
cc    pecent=pecent*vcell_sim/vcell
c     pe=pecent+pe_en+pe_ee
c     write(6,'(''pe,pecent,pe_en,pe_ee'',9f10.5)') pe,pecent,pe_en,pe_ee

      call distances(xold,pe)

      dist_en=1.d10
      do 110 i=1,ncent
        do 110 j=1,nelec
  110     dist_en=min(dist_en,r_en(j,i))
      write(6,'(''dist_en='',f9.5)') dist_en

      write(6,'(''pe,pecent'',9f10.5)') pe,pecent
      c_madelung=-pe*dist_en/nelec
      write(6,'(''cryst c_madelung='',2f10.6)') pe,c_madelung

      stop
      end
c-----------------------------------------------------------------------
