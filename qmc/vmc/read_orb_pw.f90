      subroutine read_orb_pw_real
! Written by Cyrus Umrigar.
! Reads in pw basis orbitals that have already been converted to be real.
! Presently not used.

      use all_tools_mod
      use coefs_mod
      use dim_mod
      use periodic_mod
      use pworbital_mod
      implicit real*8(a-h,o-z)

      dimension rkvec_tmp(3)

      open(3,file='orbitals_pw')
      read(3,*) nkvec,ngvec
!JT      if(nkvec.gt.MKPTS) stop 'nkvec>MKPTS in read_orb_pw'


      call alloc ('nband', nband, nkvec)
      jorb=0
      jorba=0
      do 50 ikv=1,nkvec
        read(3,*) ikvec,nband(ikv),(rkvec_tmp(k),k=1,ndim)
        if(ikvec.ne.ikv) stop 'ikvec.ne.ikv in read_orb_pw_real'
        do 10 k=1,ndim
          if(abs(rkvec_tmp(k)-rkvec(k,ikv)).gt.1.d-5) then
            write(6,'(''rkvec_tmp!=rkvec in read_orb_pw_tm.  Since kvecs are now generated in standard order indep of cutg_sim_big'' &
     &      ,'' likely reasons are that orb_pw_tm needs to be regenerated with kvecs in new order or the k-vec. shift is not right'' &
     &      )')
            stop 'rkvec_tmp!=rkvec in read_orb_pw_tm.  Likely reasons are orb_pw_tm needs to be regenerated with kvecs in new order &
      &or k-vec shift is wrong'
          endif
   10   continue
        do 50 iband=1,nband(ikv)
          jorb=jorb+1
          jorba=jorba+k_inv(ikv)
          read(3,*) ib,eig
          if(ib.ne.iband) stop 'ib.ne.iband in read_orb_pw_real'
          write(6,'(''iband,eig='',i3,f9.5)') ib,eig
          call alloc ('c_rp', c_rp, ngvec, jorb)
          call alloc ('c_rm', c_rm, ngvec, jorb)
          call alloc ('c_ip', c_ip, ngvec, jorb)
          call alloc ('c_im', c_im, ngvec, jorb)
   50     read(3,*) (c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb),igv=1,ngvec)

! Note that jorba can be > nord if ndet>1
      write(6,'(i3,'' orbitals read in from file orbitals_pw'')') jorb
      if(jorba.lt.norb) then
        write(6,'(''jorba,norb='',2i5)') jorba,norb
        stop 'jorba < norb in read_orb_pw'
      endif
      close(3)

      return
      end
!-----------------------------------------------------------------------

      subroutine read_orb_pw
! Written by Cyrus Umrigar.  Modified by William Parker to interface to Einspline library for interpolating B-splines.
! Reads in pw basis orbitals and convert them to real ones suitable for qmc.
! Warning: At present NGVECX is used to dimension not only quantities that are
! used for the Ewald sum, but also quantities used for the wavefunction pw coefficients.
! There is no reason for the latter to be tied to the former.

! I write out orbitals_pw_lagrange so that in future runs I can just read that file in
! rather than orbitals_pw_tm, but at the moment I am not using that feature.
! Also, I first write out a temporary fort.3 and then delete it just because
! it is only after one has processed all the k-pts that one knows how big ngvec_orb is.
! However, that causes problems when running with mpi, so comment out that part.

      use all_tools_mod
      use bwfdet_mod
      use bsplines_mod
      use orbital_grid_mod
      use atom_mod
      use dorb_mod
      use orbe_mod
      use tempor_test_mod
      use coefs_mod
      use dets_mod
      use const_mod
      use dim_mod
      use contr2_mod
      use contr3_mod
      use periodic_mod
      use contr_names_mod
      implicit real*8(a-h,o-z)
      character*20 fmt

      parameter(eps=1.d-3)

      dimension ipoint(norb)
      real*8 r_basis(3),xi,yi,zi


      write(6,'(/,''Reading in orbitals for periodic system'',/)')

      write(6,'(''ngvec='',i6)') ngvec ; call systemflush(6)

! Factor for renormalizing orbitals to avoid overflow when calculating determinant.
! If number of electrons is small do not renormalize, so old outputs do not change.
      if(nelec.le.256) then
        rnorm=1.d0
       else
        rnorm=0.1d0
        write(6,'(''Info: orbitals renormalized by 0.1 to prevent overflow'')')
      endif

! Flag the orbitals in orbitals_pw_tm that are actually used
! norb in the input file is >= norb actually used, since some may be skipped.
! Reset norb to the number actually used
! JT: if iorb_used=0, then use all orbitals
      call alloc ('iflag', iflag, norb)
      do 4 i=1,norb
        if (iorb_used.eq.0) then
         iflag(i)=1
        else
         iflag(i)=0
        endif
    4  continue
      do 5 idet=1,ndet
        do 5 ielec=1,nelec
    5     iflag(iworbd(ielec,idet))=1
      norb_used=0
      do 6 iorb=1,norb
        if(iflag(iorb).eq.1) then
          norb_used=norb_used+1
          ipoint(iorb)=norb_used
        endif
    6 continue

      if(norb_used.lt.norb) then
        write(6,'(/,''norb(read in), norb(used)='',2i5)') norb,norb_used
        write(6,'(/,''new mapping of orbitals in determinants'')')
        do 8 idet=1,ndet
          do 7 ielec=1,nelec
    7       iworbd(ielec,idet)=ipoint(iworbd(ielec,idet))
          if(nup+ndn.lt.60) then
            write(fmt,'(''('',i2,''i3,3x,'',i2,''i3)'')') nup,ndn
            write(6,fmt) (iworbd(j,idet),j=1,nup),(iworbd(j+nup,idet),j=1,ndn)
           else
            write(6,'(30i4)') (iworbd(j,idet),j=1,nup)
            write(6,'(30i4)') (iworbd(j+nup,idet),j=1,ndn)
          endif
    8   continue
        norb=norb_used
      endif

      call alloc ('orb', orb, norb)
      call alloc ('dorb', dorb, 3, norb)
      call alloc ('ddorb', ddorb, norb)

! Set coordinates of test point
      r(1)=.1d0+cent(1,1)
      r(2)=.2d0+cent(2,1)
      r(3)=.3d0+cent(3,1)

! Use interpolated orbitals if inum_orb.ne.0
      if(inum_orb.ne.0) then

        if(abs(inum_orb).eq.4) then
          write(6,'(''Using Lagrange polynomial interpolation'')')
         elseif(abs(inum_orb).eq.6) then
          write(6,'(''Using approximating B-spline'')')
         elseif(abs(inum_orb).eq.8) then
          write(6,'(''Using interpolating B-spline'')')
        endif

        num_orb_exist=0

! Read in numerical orbitals on grid if file orbitals_num_lagrange exists and has correct mesh
! For Lagrange read in orbitals, gradient and Laplacian; for interpolating B-splines read in orbitals only

!       if(abs(inum_orb).eq.4 .or. abs(inum_orb).eq.8) then
        if(abs(inum_orb).eq.4) then
          open(4,file='orbitals_num_lagrange',form='unformatted',status='old',err=10)
          num_orb_exist=1
!         write(6,'(''Lagrange interpolation grid is'',3i5)') ngrid_orbx,ngrid_orby,ngrid_orbz
          read(4) ngrid_orbxf,ngrid_orbyf,ngrid_orbzf
          if(ngrid_orbxf.ne.ngrid_orbx .or. ngrid_orbyf.ne.ngrid_orby &
     &       .or.  ngrid_orbzf.ne.ngrid_orbz) then
            write(6,'(''orbital grids do not match, program, orbitals_num:'',3i4,x,3i4)') &
     &      ngrid_orbx,ngrid_orby,ngrid_orbz,ngrid_orbxf,ngrid_orbyf,ngrid_orbzf
            stop 'orbital grids do not match'
          endif
          read(4) ((((orb_num(iorb,ix,iy,iz),iorb=1,norb),ix=0, &
     &             ngrid_orbx-1),iy=0,ngrid_orby-1),iz=0,ngrid_orbz-1)
          if(abs(inum_orb).eq.4) then
            read(4) ((((ddorb_num(iorb,ix,iy,iz),iorb=1,norb),ix=0, &
     &             ngrid_orbx-1),iy=0,ngrid_orby-1),iz=0,ngrid_orbz-1)
!           read(4) (((((dorb_num(k,iorb,ix,iy,iz),k=1,ndim),iorb=1,norb),
!    &          ix=0,ngrid_orbx-1),iy=0,ngrid_orby-1),iz=0,ngrid_orbz-1)
! I break up the loop over k because otherwise the ifort compiler
! complains that record is too big on reading it back in
            do 9 k=1,3
    9         read(4) ((((dorb_num(k,iorb,ix,iy,iz),iorb=1,norb),ix=0, &
     &               ngrid_orbx-1),iy=0,ngrid_orby-1),iz=0,ngrid_orbz-1)
          endif
          write(6,'(''Done reading orbitals_num_lagrange'')')
          close(4)
        endif

!wparker Read in B-spline coefficients from file
        if(inum_orb.eq.6 .or. inum_orb.eq.-6) then
          num_orb_exist=1
          write(6,*)
          write(6,*)'Reading blip wave function and associated data'
          write(6,*)'=============================================='
!wparker pecent is reset later in the read_input subroutine
          call readbwf(pecent)
          call bwfdet_setup(rnorm)
!     ! WAS
          ngvec_orb = nwvec !! defined in module bwf
          call object_modified ("ngvec_orb")
!     !
          write(6,'(''Done with approximating B-spline setup'')')
        endif

        if(num_orb_exist.eq.1) goto 100

      endif

   10 if(inum_orb.ne.0 .and. num_orb_exist.eq.0) &
     &write(6,'(''Warning: orbitals_num_lagrange either does not exist (which is OK) or not read correctly'')')

! Read in orbitals in Jose-Luis Martins or PWSCF format
      if(index(iorb_format,'tm').ne.0) then
        write(6,'(''Reading in orbitals in Jose-Luis Martins format'')')
        call read_orb_pw_tm
       elseif(index(iorb_format,'pwscf').ne.0) then
        write(6,'(''Reading in orbitals in PWSCF format'')')
        call read_orb_pw_pwscf
       else
        stop 'iorb_format should be tm or pwscf'
      endif

      nsum=0
      do 60 i=1,ngnorm
        nsum=nsum+igmult(i)
        if(nsum.ge.ngvec_orb) then
          ngnorm_orb=i
          goto 70
        endif
   60 continue
   70 write(6,'(''ngnorm_orb,ngvec_orb='',9i6)') ngnorm_orb,ngvec_orb

! Test to see if orbitals and derivs. calculated smart way are correct by comparing to dumb way from above
      call my_second(1,'orb_co')
!1    nelec_sav=nelec
!1    nelec=1
!1    call orbitals_pw(r,orb,dorb,ddorb)
      call orbitals_pw_grade(r,orb,dorb,ddorb)
      write(6,'(''orb_complic='',2i3,5d15.8)') (iorb,ireal_imag(iorb),orb(iorb),ddorb(iorb), &
     &(dorb(k,iorb),k=1,ndim),iorb=1,norb)
      call my_second(2,'orb_co')

! Check for linear dependencies among orbitals
      write(6,'(/,''Checking for linear dependency among orbitals'',/)')
      istop=0
      do 72 i=2,norb
        do 72 j=1,i-1
          idep=1
          ratio=orb(i)/orb(j)
          if(abs(ratio*(ddorb(j)/ddorb(i))-1).gt.eps) then
            idep=0
          endif
          do 71 k=1,ndim
            if(abs(ratio*dorb(k,j)/dorb(k,i)-1).gt.eps) then
              idep=0
            endif
   71     continue
          if(idep.eq.1) then
            write(6,'(''Warning: orbitals'',i4,'' and'',i4,'' are linearly dependent'')') i,j
            istop=1
          endif
   72   continue

      if(istop.eq.1) stop 'looks like orbitals are linearly dependent'

! Check if orbitals and derivs. calculated by slow and fast method are the same.
      do 73 i=1,norb
        if(abs(orb(i)-orb_si(i)).gt.1.d-10) then
            write(6,'(''i,orb(i),orb_si(i),orb(i)-orb_si(i)='',i5,9d21.14)') &
     &      i,orb(i),orb_si(i),orb(i)-orb_si(i)
          stop 'orb(i).ne.orb_si(i) in read_orb_pw'
        endif
        if(abs(ddorb(i)-ddorb_si(i)).gt.1.d-10) then
            write(6,'(''Warning: i,ddorb(i),ddorb_si(i),ddorb(i)-ddorb_si(i)='',i5,9d21.14)') &
     &      i,ddorb(i),ddorb_si(i),ddorb(i)-ddorb_si(i)
          if(abs(ddorb(i)-ddorb_si(i)).gt.1.d-3) stop 'ddorb(i).ne.ddorb_si(i) in read_ddorb_pw'
        endif
        do 73 k=1,ndim
          if(abs(dorb(k,i)-dorb_si(k,i)).gt.1.d-10) then
            write(6,'(''k,i,dorb(k,i),dorb_si(k,i),dorb(k,i)-dorb_si(k,i)='',2i5,9d21.14)') &
     &      k,i,dorb(k,i),dorb_si(k,i),dorb(k,i)-dorb_si(k,i)
            stop 'dorb(k,i).ne.dorb_si(k,i) in read_orb_pw'
          endif
   73 continue

!1    nelec=nelec_sav

! Calculate orbitals on grid and save them if orbitals_num does not exist
      if(inum_orb.ne.0 .and. num_orb_exist.eq.0) then

!1      nelec_sav=nelec
!1      nelec=1

        call my_second(1,'orb_pw')

! Calculate orbitals at grid points for Lagrange and interpolating B-spline interpolation

!       if(abs(inum_orb).eq.4 .or. abs(inum_orb).eq.8) then
        if(abs(inum_orb).eq.4) then

          do 76 ix=0,ngrid_orbx-1
            r_basis(1)=ix/dfloat(ngrid_orbx)
            do 76 iy=0,ngrid_orby-1
              r_basis(2)=iy/dfloat(ngrid_orby)
              do 76 iz=0,ngrid_orbz-1
                r_basis(3)=iz/dfloat(ngrid_orbz)
!               write(6,'(''ix,iy,iz,r_basis'',3i3,9f8.4)') ix,iy,iz,r_basis(1),r_basis(2),r_basis(3)

! Convert to cartesian coodinates
              do 74 k=1,ndim
                r(k)=0
                do 74 i=1,ndim
   74             r(k)=r(k)+rlatt_sim(k,i)*r_basis(i)

              call orbitals_pw_grade(r,orb,dorb,ddorb)
!             write(6,'(''orb_complic='',i3,5f12.8)') (iorb,orb(iorb),ddorb(iorb),(dorb(k,iorb),k=1,ndim),iorb=1,norb)
              do 76 iorb=1,norb
!               write(6,'(''ix'',4i2,9f8.4)')ix,iy,iz,iorb,(r_basis(k),k=1,ndim),(r(k),k=1,ndim),orb(iorb)
                orb_num(iorb,ix,iy,iz)=orb(iorb)
                ddorb_num(iorb,ix,iy,iz)=ddorb(iorb)
                do 76 k=1,ndim
   76             dorb_num(k,iorb,ix,iy,iz)=dorb(k,iorb)

!wparker End if block for Lagrange interpolation setup and printout
        endif

        if(inum_orb.eq.6 .or. inum_orb.eq.-6) then
          stop 'Blip data must already exist in bwfn.data.'
        endif

        call my_second(1,'orb_nu')

! Check values on grid pts.
!       do 78 ix=0,ngrid_orbx-1
!       r_basis(1)=ix/dfloat(ngrid_orbx)
!       do 78 iy=0,ngrid_orby-1
!       r_basis(2)=iy/dfloat(ngrid_orby)
!       do 78 iz=0,ngrid_orbz-1
!       r_basis(3)=iz/dfloat(ngrid_orbz)

!cConvert to cartesian coodinates
!       do 77 k=1,ndim
!         r(k)=0
!         do 77 i=1,ndim
!  77       r(k)=r(k)+rlatt_sim(k,i)*r_basis(i)

!c      call orbitals_pw_grade(r,orb,dorb,ddorb)
!c      write(6,'(''orb_complic2='',i3,5f12.8)') (iorb,orb(iorb),ddorb(iorb),(dorb(k,iorb),k=1,ndim),iorb=1,norb)
!  78   call orbitals_period_num_grade(r,orb,dorb,ddorb)
!c 78   write(6,'(''orb_complic3='',i3,5f12.8)') (iorb,orb(iorb),ddorb(iorb),(dorb(k,iorb),k=1,ndim),iorb=1,norb)

        if(index(mode,'mpi').eq.0 .or. idtask.eq.0) then

! Write to file for later use only if inum_orb.eq.4, not -4.
!         if(inum_orb.eq.4 .or. inum_orb.eq.8) then
          if(inum_orb.eq.4) then
            open(4,file='orbitals_num_lagrange',form='unformatted',status='new')
            write(4) ngrid_orbx,ngrid_orby,ngrid_orbz
            write(4) ((((orb_num(iorb,ix,iy,iz),iorb=1,norb),ix=0,ngrid_orbx-1),iy=0,ngrid_orby-1),iz=0,ngrid_orbz-1)
            if(abs(inum_orb).eq.4) then
              write(4) ((((ddorb_num(iorb,ix,iy,iz),iorb=1,norb),ix=0,ngrid_orbx-1),iy=0,ngrid_orby-1),iz=0,ngrid_orbz-1)
!             write(4) (((((dorb_num(k,iorb,ix,iy,iz),k=1,ndim),iorb=1,norb),ix=0,ngrid_orbx-1),iy=0,ngrid_orby-1),iz=0,ngrid_orbz-1)
! I break up the loop over k because otherwise the ifort compiler complains that record is too big on reading it back in
              do 79 k=1,3
   79         write(4) ((((dorb_num(k,iorb,ix,iy,iz),iorb=1,norb),ix=0,ngrid_orbx-1),iy=0,ngrid_orby-1),iz=0,ngrid_orbz-1)
            endif
            close(4)
          endif
        endif ! mpi or idtask.eq.0

        call my_second(2,'orb_nu')

!1      nelec=nelec_sav

      endif

! Write file for subsequent read-in, though at present I am not using it.
! Comment it out since it causes problems with mpi.
!     open(4,file='orbitals_pw')
!     write(4,'(i1,3i5,'' icmplx,nkvec,ngnorm_orb,ngvec_orb'')') icmplx,nkvec,ngnorm_orb,ngvec_orb
!     rewind 3
!     read(3,*) nkvec_tmp,ngvec_tmp
!     do 80 ikv=1,nkvec
!       read(3,'(2i4,3f9.5)') ikv_tmp,nband(ikv),(rkvec_tmp(k),k=1,ndim)
!       write(4,'(2i4,3f9.5'' ikvec, nband, rkvec(in recip. lat. units)'')') ikv,nband(ikv),(rkvec_tmp(k),k=1,ndim)
!       do 80 iband=1,nband(ikv)
!         read(3,'(2i5,f10.6)') ikv_tmp,iband_tmp,eig
!         write(4,'(2i5,f10.6,'' ikvec, iband, eig (Ha)'')') ikv,iband,eig
!         if(k_inv(ikv).eq.1) then
!           read(3,'(1p2d22.14)') (c_rp(igv,jorb),c_rm(igv,jorb),igv=1,ngvec)
!           write(4,'(1p2d22.14)') (c_rp(igv,jorb),c_rm(igv,jorb),igv=1,ngvec_orb)
!          else
!           read(3,'(1p4d22.14)') (c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb),igv=1,ngvec)
!           write(4,'(1p4d22.14)') (c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb),igv=1,ngvec_orb)
!         endif
!  80     continue

!     close(3,status='delete')
!     close(4)

  100 if(abs(inum_orb).eq.8) then
#ifdef NOEINSPLINE
          write(6,*) 'the code must be linked to einspline library'
          stop 'the code must be linked to einspline library'
#else
!       call setup_bsplines_coefficients(ngrid_orbx,ngrid_orby,ngrid_orbz)
        call setup_bsplines_coefficients
#endif

        write(6,'(''Done setting up interpolating B-spline coeffs'')')
      endif

      return

      end
!-----------------------------------------------------------------------

      subroutine read_orb_pw_tm
! Written by Cyrus Umrigar
! Reads in pw basis orbitals in Jose-Luis Martins' format and convert them to real ones suitable for qmc.
! Warning: At present NGVECX is used to dimension not only quantities that are
! used for the Ewald sum, but also quantities used for the wavefunction pw coefficients.
! There is no reason for the latter to be tied to the former.

! I write out orbitals_pw so that in future runs I can just read that file in
! rather than orbitals_pw_tm, but at the moment I am not using that feature.
! Also, I first write out a temporary fort.3 and then delete it just because
! it is only after one has processed all the k-pts that one knows how big ngvec_orb is.
! However, that causes problems when running with mpi, so comment out that part.

      use all_tools_mod
      use orbitals_mod
      use tempor_test_mod
      use coefs_mod
      use const_mod
      use dim_mod
      use contr3_mod
      use periodic_mod
      use pworbital_mod
      implicit real*8(a-h,o-z)
      character*160 title2 ! name it title2 because title is being passed here from control_mod.f90
      parameter(eps=1.d-6)


! igvec_dft needs to be dimensioned with NGVEC_BIGX since in file orbitals_pw_tm the
! list of g vectors at the top is longer than what is actually used.
! The other arrays are dimensioned NGVEC2X rather than NGVECX because planewave code does not
! combine coefs. of G and -G, whereas QMC code does.

      call alloc ('orb', orb, norb)
      call alloc ('dorb', dorb, 3, norb)
      call alloc ('ddorb', ddorb, norb)
!JT      call alloc ('orb_si', orb_si, norb)
!JT      call alloc ('dorb_si', dorb_si, 3, norb)
!JT      call alloc ('ddorb_si', ddorb_si, norb)
      call alloc ('ireal_imag', ireal_imag, norb)

      call file_exist_or_die (file_orbitals_pw_tm_in)
      open(30,file=file_orbitals_pw_tm_in,err=999)

! position file to skip comments
      write(6,'(/,''Reading orbitals from '',a)') trim(file_orbitals_pw_tm_in)
      title2(1:1)='#'
      do while(title2(1:1).eq.'#')
        read(30,'(a)') title2
        write(6,'(a)') trim(title2)
      enddo

!     read(30,*) icmplx,ngvec_dft
      read(title2,*) icmplx,ngvec_dft
!JT      if(ngvec_dft.gt.NGVEC_BIGX) then
!JT        write(6,'(''ngvec_dft,NGVEC_BIGX,NGVECX,NGNORMX'',9i10)') ngvec_dft,NGVEC_BIGX,NGVECX,NGNORMX
!JT        stop 'ngvec_dft > NGVEC_BIGX in read_orb_pw_tm'
!JT      endif
      call alloc ('igvec_dft', igvec_dft, 3, ngvec_dft)
      do 20 i=1,ngvec_dft
   20   read(30,*) (igvec_dft(k,i),k=1,ndim)
!  20   write(6,*) (igvec_dft(k,i),k=1,ndim)

      read(30,*) nkvec_tmp
      if(nkvec_tmp.ne.nkvec) then
        write(6,'(''nkvec_tmp,nkvec='',9i5)') nkvec_tmp,nkvec
        stop 'nkvec_tmp != nkvec in read_orb_pw_tm'
      endif

      if(ipr.ge.1 .and. (index(mode,'mpi').eq.0 .or. idtask.eq.0)) write(3,'(2i6,'' nkvec,ngvec'')') nkvec,ngvec
      if(ipr.ge.1) write(6,'(2i6,'' nkvec,ngvec'')') nkvec,ngvec
!JT      if(nkvec.gt.MKPTS) stop 'nkvec>MKPTS in read_orb_pw_tm'

      call my_second(1,'orb_si')

! iorb  goes over all orbitals
! iorba goes over all orbs and takes into account that for k.ne.G/2 we get 2 indep.
!       orbs by combining Psi_k with Psi_-k.
! jorb  goes over all occup. orbitals
! jorba goes over all occup. orbitals and takes into account that for k.ne.G/2 we get 2 indep.
!       orbs by combining Psi_k with Psi_-k.
      iorba=0
      jorb=0
      jorba=0
      ngvec_orb=0
      eigmax=-1.d99
      eigmin=1.d99
      call alloc ('ngg', ngg, nkvec)
      call alloc ('nband', nband, nkvec)
      do 90 ikv=1,nkvec
        read(30,*) ikvec,nband(ikv),ngvec_dftorb,(rkvec_tmp(k),k=1,ndim)
        call object_modified ('nband')
        if(ikvec.ne.ikv) stop 'ikvec.ne.ikv in read_orb_pw_tm'
!JT        if(ngvec_dftorb.gt.NGVEC2X) stop 'ngvec_dftorb>NGVEC2X in read_orb_pw_tm'
        ngg(ikv)=ngvec_dftorb
        if(icmplx.eq.0) then
          call alloc ('c_imag', c_imag, ngvec_dftorb)
          do 21 ig=1,ngvec_dftorb
   21       c_imag(ig)=0
        endif

        write(6,'(''ikvec, nband='',2i4)') ikv,nband(ikv)
!       if(ipr.ge.1 .and. (index(mode,'mpi').eq.0 .or. idtask.eq.0))
!    &  write(3,'(2i4,3f9.5'' ikvec, nband, rkvec(in cartesian units)'')') ikv,nband(ikv),(rkvec(k,ikv),k=1,ndim)
        if(ipr.ge.1 .and. (index(mode,'mpi').eq.0 .or. idtask.eq.0)) &
     &  write(3,'(2i4,3f9.5'' ikvec, nband, rkvec(in recip. lat. units)'')') ikv,nband(ikv),(rkvec_tmp(k),k=1,ndim)

        do 22 k=1,ndim
   22     rkvec_tmp2(k)=rkvec_tmp(k)
        do 23 k=1,ndim
          rkvec_tmp(k)=0
          do 23 i=1,ndim
   23       rkvec_tmp(k)=rkvec_tmp(k)+rkvec_tmp2(i)*glatt(k,i)
        write(6,'(/,''rkvec_tmp in recip. lat. vec. units'',9f9.4)') (rkvec_tmp2(k),k=1,ndim)
        write(6,'(''rkvec_tmp in cartesian coodinates'',9f9.4)') (rkvec_tmp(k),k=1,ndim)
        do 24 k=1,ndim
          if(abs(rkvec_tmp(k)-rkvec(k,ikv)).gt.1.d-5) then
            write(6,'(''kvec='',9f9.6)') (kvec(kk,ikv)+rkvec_shift(kk),kk=1,ndim)
            write(6,'(''rkvec_tmp,rkvec='',9f9.6)') (rkvec_tmp(kk),kk=1,ndim),(rkvec(kk,ikv),kk=1,ndim)
            write(6,'(''rkvec_tmp!=rkvec in read_orb_pw_tm.  Since kvecs are now generated in standard order indep of cutg_sim_big'' &
     &      ,'' Likely reasons are that orb_pw_tm needs to be regenerated with kvecs in new order or the k-vec. shift is not right'' &
     &      )')
            stop 'rkvec_tmp!=rkvec in read_orb_pw_tm.  Likely reasons are orb_pw_tm needs to be regenerated with kvecs in new order &
      &or k-vec shift is wrong'
          endif
   24   continue
!       if(ngvec_dftorb.gt.NGVEC2X) stop 'ngvec_dftorb>NGVEC2X in read_orb_pw_tm'
        call alloc ('iwgvec', iwgvec, ngvec_dftorb)
        read(30,*) (iwgvec(j),j=1,ngvec_dftorb)

! Establish the mapping between DFT and QMC g-vectors.
! Note that the DFT g-vectors for each k-pt are different and are themselves mapped
! to the list of gvectors at beginning of orbitals_pw_tm file.
        call alloc ('map_gvecdft_gvec', map_gvecdft_gvec, ngvec_dftorb)
        call alloc ('isign_gvecdft_gvec', isign_gvecdft_gvec, ngvec_dftorb)
        ngvec_found=0
        do 35 igv=1,ngvec
          if(igvec(1,igv).eq.0 .and. igvec(2,igv).eq.0 .and. igvec(3,igv).eq.0) then
            isign_min=1
           else
            isign_min=-1
          endif
          do 30 ig=1,ngvec_dftorb
            do 30 isign=1,isign_min,-2
              norm=0
!             write(6,*) (igvec_dft(k,iwgvec(ig)),k=1,ndim),(igvec(k,igv),k=1,ndim)
              do 25 k=1,ndim
   25           norm=norm+(igvec_dft(k,iwgvec(ig))-isign*igvec(k,igv))**2
              if(norm.eq.0) then
                ngvec_found=ngvec_found+1
                ngvec_orb=max(ngvec_orb,igv)
                map_gvecdft_gvec(ig)=igv
                isign_gvecdft_gvec(ig)=isign
!               write(6,'(''igv,ig,isign,ngvec_found'',9i5)') igv,ig,isign,ngvec_found
              endif
   30     continue
!         write(6,'(''igv,jorb,c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb)'',2i5,9d12.4)')
!    & igv,jorb,c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb)
   35   continue

        call object_modified ('ngvec_orb')

        if(ngvec_found.ne.ngvec_dftorb) then
          write(6,'(''ngvec_dftorb,ngvec_found='',2i5)') ngvec_dftorb,ngvec_found
          if(ipr.ge.1 .and. (index(mode,'mpi').eq.0 .or. idtask.eq.0)) &
     &    write(3,'(''ngvec_dftorb,ngvec_found='',2i5)') ngvec_dftorb,ngvec_found
          if(ngvec_found.lt.ngvec_dftorb) then
             write(6,'(''Increase cutg to about'',f6.2,'' or more'')') cutg*(dfloat(ngvec_dftorb)/ngvec_found)**(1.d0/3.d0)
             stop 'probably need to increase cutg to generate more g-vectors'
          endif
          stop 'ngvec_found != ngvec_dftorb in read_orb_pw_tm'
        endif

        nband_tmp=0
        do 80 iband=1,nband(ikv)
          iorba=iorba+k_inv(ikv)
          if(iorba > norb) then
             call alloc ('iflag', iflag, iorba)
             iflag(norb+1:iorba)=0
          endif
!JT          if(iorba.gt.MORB) stop 'iorba>MORB in read_orb_pw_tm'
          morb = max (morb, iorba) !JT
          read(30,*) ibandx,eig
          if(ibandx.ne.iband) stop 'ibandx.ne.iband in read_orb_pw_tm'
          call alloc ('c_real', c_real, ngvec_dftorb)
          if(icmplx.ne.0) then
            call alloc ('c_imag', c_imag, ngvec_dftorb)
            read(30,*) (c_real(ig),c_imag(ig),ig=1,ngvec_dftorb)
           else
            read(30,*) (c_real(ig),ig=1,ngvec_dftorb)
          endif

! eigmin is the energy of the lowest unocc. orb, eigmax that of the highest occ. one.
! I have replaced lines below with double 'if' lines because if we do not then
! (iorba-1) may be 0 when k_inv(ikv).eq.1 and accessing iflag(0) is illegal.
!         if(k_inv(ikv).eq.2.and.iflag(iorba-1).ne.iflag(iorba)) stop
!    &    'if k_inv=2 then the 2 indep. states should have same occupancy
!    &    (except for some excited states)'
!         if((k_inv(ikv).eq.1.and.iflag(iorba).eq.0) .or.
!    &    (k_inv(ikv).eq.2.and.iflag(iorba-1).eq.0.and.iflag(iorba).eq.0)) then
!           eigmin=min(eigmin,eig)
!           goto 80
!         endif
          if(k_inv(ikv).eq.2) then
            if(iflag(iorba-1).ne.iflag(iorba)) then
              write(6,'(''ikv,k_inv(ikv),iband,iorba,eig='',4i5,9f9.5)') ikv,k_inv(ikv),iband,iorba,eig
              stop 'if k_inv=2 then the 2 indep. states should have same occupancy (except for some excited states). &
     & Likely reason is iworbd is incorrect'
            endif
          endif
          if(k_inv(ikv).eq.1.and.iflag(iorba).eq.0) then
            eigmin=min(eigmin,eig)
            goto 80
          endif
          if(k_inv(ikv).eq.2) then
            if(iflag(iorba-1).eq.0.and.iflag(iorba).eq.0) then
              eigmin=min(eigmin,eig)
              goto 80
            endif
          endif

          eigmax=max(eigmax,eig)
          jorb=jorb+1
          jorba=jorba+k_inv(ikv)
!JT          if(jorba.gt.MORB_OCC) stop 'jorba > MORB_OCC in read_orb_pw_tm'
          morb = max (morb, jorba+1) !JT
          nband_tmp=nband_tmp+1

! If there is only one linearly indep. state formed from psi_k and psi_-k then
! determine if that state is real or imaginary.  This is possibly not reliable
! so redo it later using values of orbitals at some point.
          if(k_inv(ikv).eq.1) then
            if(rknorm(ikv).eq.0.d0) then
              ig_min=2
             else
              ig_min=1
            endif
            sum=0
            sum_abs=0
            do 40 ig=ig_min,ngvec_dftorb
              sum=sum+c_real(ig)
   40         sum_abs=sum_abs+abs(c_real(ig))
            if(abs(sum/sum_abs).gt.1.d-6) then
              ireal_imag(jorba)=1
             else
              ireal_imag(jorba)=2
            endif
            if(ipr.ge.1) write(6,'(''ikv,iband,ireal_imag,sum,sum_abs='',3i4,9d12.4)') &
     &      ikv,iband,ireal_imag(jorba),sum,sum_abs
           else
            ireal_imag(jorba-1)=0
            ireal_imag(jorba)=0
          endif

! Set ngvec of them to 0 because we do not know until we have processed all k-pts
! what the final value of ngvec_orb will be, and ngvec is an upper bound to ngvec_orb.
          call alloc ('c_rp', c_rp, ngvec, jorb)
          call alloc ('c_rm', c_rm, ngvec, jorb)
          call alloc ('c_ip', c_ip, ngvec, jorb)
          call alloc ('c_im', c_im, ngvec, jorb)
          do 45 igv=1,ngvec
            c_rp(igv,jorb)=0
            c_rm(igv,jorb)=0
            c_ip(igv,jorb)=0
   45       c_im(igv,jorb)=0

          do 50 ig=1,ngvec_dftorb
            igv=map_gvecdft_gvec(ig)
            isign=isign_gvecdft_gvec(ig)
            c_rp(igv,jorb)=c_rp(igv,jorb)+c_real(ig)
            c_rm(igv,jorb)=c_rm(igv,jorb)+c_real(ig)*isign
            c_ip(igv,jorb)=c_ip(igv,jorb)+c_imag(ig)
   50       c_im(igv,jorb)=c_im(igv,jorb)+c_imag(ig)*isign
!           write(6,'(''igv,jorb,c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb)'',2i5,9d12.4)')
!    & igv,jorb,c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb)

          do 60 igv=1,ngvec
            c_rp(igv,jorb)=rnorm*c_rp(igv,jorb)
            c_rm(igv,jorb)=rnorm*c_rm(igv,jorb)
            c_ip(igv,jorb)=rnorm*c_ip(igv,jorb)
   60       c_im(igv,jorb)=rnorm*c_im(igv,jorb)
!         call my_second(2,'42    ')

          call object_modified ('c_rp')
          call object_modified ('c_rm')
          call object_modified ('c_ip')
          call object_modified ('c_im')

          if(ipr.ge.0) write(6,'(i5,f10.6,'' iband, eig (Ha)'')') iband,eig
          if(ipr.ge.1 .and. (index(mode,'mpi').eq.0 .or. idtask.eq.0)) then
            write(3,'(i5,f10.6,'' iband, eig (Ha)'')') iband,eig
            if(k_inv(ikv).eq.1) then
              write(3,'(1p2d22.14)') (c_rp(igv,jorb),c_rm(igv,jorb),igv=1,ngvec)
             else
              write(3,'(1p4d22.14)') (c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb),igv=1,ngvec)
            endif
          endif

! We calculate orbitals dumb way and then smart way so that they can be compared
! by eye to make sure smart way is right.
! Calculation of orbitals dumb way with orbitals_pw2 is time consuming.
! Also, choose which state to keep when there is only one independent state (k=G/2)
!     call my_second(1,'orb_s1')
! Test to see if orbitals and derivs. calculated correctly
          call orbitals_pw2(ikv,iband,jorba)
! If there is only 1 independent state, choose it to be the one with the largest absolute value
! unless it is linearly dependent on an already chosen state
          if(k_inv(ikv).eq.1) then

            if(jorba.ge.2) then
              if(orb_si(jorba+1)*ddorb_si(jorba+1).eq.0.d0 .or. &
     &        (abs(orb_si(jorba+1)*ddorb_si(jorba-1)-orb_si(jorba-1)*ddorb_si(jorba+1)).lt. &
     &        abs(eps*orb_si(jorba-1)*ddorb_si(jorba+1)) .and. &
     &        abs(orb_si(jorba+1)*dorb_si(1,jorba-1)-orb_si(jorba-1)*dorb_si(1,jorba+1)).lt. &
     &        abs(eps*orb_si(jorba-1)*dorb_si(1,jorba+1)))) then
                ireal_imag(jorba)=1
                goto 70
              endif
              if(orb_si(jorba)*ddorb_si(jorba).eq.0.d0 .or. &
     &        (abs(orb_si(jorba)*ddorb_si(jorba-1)-orb_si(jorba-1)*ddorb_si(jorba)).lt. &
     &        abs(eps*orb_si(jorba-1)*ddorb_si(jorba)) .and. &
     &        abs(orb_si(jorba)*dorb_si(1,jorba-1)-orb_si(jorba-1)*dorb_si(1,jorba)).lt. &
     &        abs(eps*orb_si(jorba-1)*dorb_si(1,jorba)))) then
                ireal_imag(jorba)=2
                goto 70
              endif
            endif
            if(jorba.ge.3) then
              if(orb_si(jorba+1)*ddorb_si(jorba+1).eq.0.d0 .or. &
     &        (abs(orb_si(jorba+1)*ddorb_si(jorba-2)-orb_si(jorba-2)*ddorb_si(jorba+1)).lt. &
     &        abs(eps*orb_si(jorba-2)*ddorb_si(jorba+1)) .and. &
     &        abs(orb_si(jorba+1)*dorb_si(1,jorba-2)-orb_si(jorba-2)*dorb_si(1,jorba+1)).lt. &
     &        abs(eps*orb_si(jorba-2)*dorb_si(1,jorba+1)))) then
                ireal_imag(jorba)=1
                goto 70
              endif
              if(orb_si(jorba)*ddorb_si(jorba).eq.0.d0 .or. &
     &        (abs(orb_si(jorba)*ddorb_si(jorba-2)-orb_si(jorba-2)*ddorb_si(jorba)).lt. &
     &        abs(eps*orb_si(jorba-2)*ddorb_si(jorba)) .and. &
     &        abs(orb_si(jorba)*dorb_si(1,jorba-2)-orb_si(jorba-2)*dorb_si(1,jorba)).lt. &
     &        abs(eps*orb_si(jorba-2)*dorb_si(1,jorba)))) then
                ireal_imag(jorba)=2
                goto 70
              endif
            endif
            if(abs(orb_si(jorba)/orb_si(jorba+1)).gt.1.d0) then
              ireal_imag(jorba)=1
             else
              ireal_imag(jorba)=2
            endif

   70       if(ireal_imag(jorba).eq.1) then
              write(6,'(''iband,ireal_imag,orb_simple='',i3,i2,5d15.8)') &
     &        iband,ireal_imag(jorba),orb_si(jorba),ddorb_si(jorba),(dorb_si(k,jorba),k=1,ndim)
! Warning: tmp
              write(6,'(''iband,           orb_simple='',i3,2x, 5d15.8)') &
     &        iband,orb_si(jorba+1),ddorb_si(jorba+1),(dorb_si(k,jorba+1),k=1,ndim)
             else
! Warning: tmp
              write(6,'(''iband,           orb_simple='',i3,2x, 5d15.8)') &
     &        iband,orb_si(jorba),ddorb_si(jorba),(dorb_si(k,jorba),k=1,ndim)

              write(6,'(''iband,ireal_imag,orb_simple='',i3,i2,5d15.8)') &
     &        iband,ireal_imag(jorba),orb_si(jorba+1),ddorb_si(jorba+1),(dorb_si(k,jorba+1),k=1,ndim)
! Save the orb_si and 2nd deriv in order to check for linear dependency
              orb_si(jorba)=orb_si(jorba+1)
              ddorb_si(jorba)=ddorb_si(jorba+1)
              do  k=1,ndim
                dorb_si(k,jorba)=dorb_si(k,jorba+1)
              enddo
            endif
           else
            ireal_imag(jorba-1)=0
            ireal_imag(jorba)=0
            write(6,'(''iband,ireal_imag,orb_simple='',i3,i2,5d15.8)') &
     &      iband,ireal_imag(jorba-1),orb_si(jorba-1),ddorb_si(jorba-1),(dorb_si(k,jorba-1),k=1,ndim)
            write(6,'(''iband,ireal_imag,orb_simple='',i3,i2,5d15.8)') &
     &      iband,ireal_imag(jorba),orb_si(jorba),ddorb_si(jorba),(dorb_si(k,jorba),k=1,ndim)
          endif

   80   continue
   90   nband(ikv)=nband_tmp
      call my_second(2,'orb_si')

      write(6,'(2i4,'' orbitals read in from file orbitals_pw_tm'')') jorb,jorba
      if(jorba.lt.norb) then
        write(6,'(''jorba,norb='',2i5)') jorba,norb
        stop 'jorba < norb in read_orb_pw_tm'
      endif

      write(6,'(/,''energy of highest  occupied orbital='',f10.6)') eigmax
      if(eigmin.ne.1.d99) then
        write(6,'(''energy of lowest unoccupied orbital='',f10.6)') eigmin
       else
        write(6,'(''no unoccupied orbitals'')')
      endif
      if(eigmin.lt.eigmax) write(6,'(''Warning: Energy of lowest unoccupied &
     &orbital is lower than that of the highest occupied one.'',/, &
     &''This may be because you are calculating an excited state, or it may be &
      &that you are calculating a ground state but the single particle'',/, &
     &''band structure has a band overlap, though in fact there is none.'')')

      close(30)
      return

  999 write(6,'(''Error: file orbitals_pw_tm is missing'')')
      stop 'file orbitals_pw_tm is missing'
      end
!-----------------------------------------------------------------------

      subroutine read_orb_pw_pwscf
! Written by Cyrus Umrigar
! Reads in pw basis orbitals in PWSCF format and convert them to real ones suitable for qmc.
! Warning: At present NGVECX is used to dimension not only quantities that are
! used for the Ewald sum, but also quantities used for the wavefunction pw coefficients.
! There is no reason for the latter to be tied to the former.

! I write out orbitals_pw so that in future runs I can just read that file in
! rather than orbitals_pw_pwscf, but at the moment I am not using that feature.
! Also, I first write out a temporary fort.3 and then delete it just because
! it is only after one has processed all the k-pts that one knows how big ngvec_orb is.
! However, that causes problems when running with mpi, so comment out that part.

      use all_tools_mod
      use atom_mod
      use tempor_test_mod
      use coefs_mod
      use const_mod
      use dim_mod
      use contr3_mod
      use periodic_mod
      use pworbital_mod
      implicit real*8(a-h,o-z)

      parameter(eps=1.d-4)


      dimension centx(3),gvec_dft(3),gvec_latt(3),rkvec_latt(3)

      complex*16 c_complex_tmp

      call alloc ('orb', orb, norb)
      call alloc ('dorb', dorb, 3, norb)
      call alloc ('ddorb', ddorb, norb)
!JT      call alloc ('orb_si', orb_si, norb)
!JT      call alloc ('dorb_si', dorb_si, 3, norb)
!JT      call alloc ('ddorb_si', ddorb_si, norb)

      call alloc ('ireal_imag', ireal_imag, norb)

! The current version of PWSCF does not exploit inversion symmetry to make the
! PW coefs. real.  So, set icmplx=1.  Dario Alfe tells me that the older versions
! did exploit inversion symmetry.  If they restore this feature then I should
! check if there is inversion symmetry about the origin and if there is then real
! plane wave coefs. are read in, otherwise complex.
      icmplx=1

      open(30,file='orbitals_pw_pwscf',err=999)

      do 12 i=1,34
   12   read(30,*)
      read(30,*) ncentx
      if(ncentx.ne.ncent) stop 'ncentx.ne.ncent in read_orb_pw_casino'
      read(30,*)
      do 14 i=1,ncent
        call systemflush(6)
        read(30,*) iznuc_allelec,(centx(k),k=1,ndim)
        do 14 k=1,ndim
! It ought to be OK to have the atom positions differ by lattice vectors.
! So, convert to lattice vector coordinates and then check if the difference modulo 1 is less than epsilon.
          centx_latt=0.d0
          cent_latt=0.d0
          do j=1,ndim
             centx_latt=centx_latt+rlatt_inv(k,j)*centx(j)
             cent_latt=cent_latt+rlatt_inv(k,j)*cent(j,i)
          enddo
          centx_latt=abs(mod(centx_latt,1.d0))
          cent_latt=abs(mod(cent_latt,1.d0))
          if(abs(centx_latt-cent_latt).gt.eps) then
             write(6,'(''k,i,centx(k),cent(k,i)='',2i5,9f9.5)') k,i,centx(k),cent(k,i)
!         if(abs(centx(k)-cent(k,i)).gt.1.d-6) then
!           write(6,'(''k,i,centx(k),cent(k,i)='',2i5,9f9.5)')
!           k,i,centx(k),cent(k,i)
          stop 'Input file and orbitals file atom coordinates do not match'
          endif
   14   continue

! Skip over reading primitive lattice vectors etc
      do 16 i=1,8
   16   read(30,*)

      read(30,*) ngvec_dft
      write(6,'(''ngvec_dft='',i6)') ngvec_dft
!JT      if(ngvec_dft.gt.NGVEC_BIGX) stop 'ngvec_dft > NGVEC_BIGX in read_orb_pw_tm'
! In orbitals_pw_tm ngvec_dftorb depends on k vector and can be smaller than ngvec_dft.
! Here it is the same.
      ngvec_dftorb=ngvec_dft

      read(30,*)
      call alloc ('igvec_dft', igvec_dft, 3, ngvec_dft)
      do 19 igv=1,ngvec_dft
        read(30,*) (gvec_dft(k),k=1,ndim)
!  19   write(6,*) (igvec_dft(k,igv),k=1,ndim)
        do 19 k=1,ndim
          gvec_latt(k)=0
          do 17 i=1,ndim
   17       gvec_latt(k)=gvec_latt(k)+glatt_inv(k,i)*gvec_dft(i)
          if(abs(gvec_latt(k)-nint(gvec_latt(k))).gt.1.d-6) then
            write(6,'(''gvec_latt(k),nint(gvec_latt(k))='',f9.5,i5)') gvec_latt(k),nint(gvec_latt(k))
            stop 'gvec_latt(k)-nint(gvec_latt(k)).gt.1.d-10'
          endif
   19     igvec_dft(k,igv)=nint(gvec_latt(k))


      do 20 i=1,4
   20   read(30,*)

      read(30,*) nkvec_tmp
      write(6,'(''nkvec_tmp='',i5)') nkvec_tmp
      if(nkvec_tmp.ne.nkvec) then
        write(6,'(''nkvec_tmp,nkvec='',9i5)') nkvec_tmp,nkvec
        stop 'nkvec_tmp != nkvec in read_orb_pw_pwscf'
      endif

      if(ipr.ge.0) write(6,'(2i6,'' nkvec,ngvec'')') nkvec,ngvec
      if(ipr.ge.1 .and. (index(mode,'mpi').eq.0 .or. idtask.eq.0)) write(3,'(2i6,'' nkvec,ngvec'')') nkvec,ngvec
!JT      if(nkvec.gt.MKPTS) stop 'nkvec>MKPTS in read_orb_pw_pwscf'

      call my_second(1,'orb_si')

! iorb  goes over all orbitals
! iorba goes over all orbs and takes into account that for k.ne.G/2 we get 2 indep.
!       orbs by combining Psi_k with Psi_-k.
! jorb  goes over all occup. orbitals
! jorba goes over all occup. orbitals and takes into account that for k.ne.G/2 we get 2 indep.
!       orbs by combining Psi_k with Psi_-k.
! It seems in PWSCF format if nband_dn is down then the same orbs are used for up and down.
! In CHAMP I do not make a distinction between up and down at this stage, so I just add the up and down number of bands at this stage.
      iorba=0
      jorb=0
      jorba=0
      ngvec_orb=0
      eigmax=-1.d99
      eigmin=1.d99
      call alloc ('ngg', ngg, nkvec)
      call alloc ('nband', nband, nkvec)
      call alloc ('k_inv', k_inv, nkvec)
      call alloc ('kvec', kvec, 3, nkvec)
      call alloc ('rkvec', rkvec, 3, nkvec)
      call alloc ('rknorm', rknorm, nkvec)
      do 90 ikv=1,nkvec
        read(30,*)
        read(30,*) ikvec,nband(ikv),nband_dn,(rkvec(k,ikv),k=1,ndim)
        if(nband_dn.ne.0) then
          write(6,'(''Different orbitals are read in for up and down bands; nband_up, nband_dn='',2i5)') nband(ikv),nband_dn
          nband(ikv)=nband(ikv)+nband_dn
        endif
        if(ikvec.ne.ikv) stop 'ikvec.ne.ikv in read_orb_pw_pwscf'
        ngg(ikv)=ngvec_dftorb
        if(icmplx.eq.0) then
          call alloc ('c_imag', c_imag, ngvec_dftorb)
          do 21 ig=1,ngvec_dftorb
   21       c_imag(ig)=0
        endif

        write(6,'(''ikvec, nband='',2i4)') ikv,nband(ikv)
!       if(ipr.ge.1 .and. (index(mode,'mpi').eq.0 .or. idtask.eq.0))
!    &  write(3,'(2i4,3f9.5'' ikvec, nband, rkvec(in cartesian units)'')') ikv,nband(ikv),(rkvec(k,ikv),k=1,ndim)

! Figure out k-vector in primitive-cell lattice vector units
        write(6,'(/,i2,'' k-vectors (shifted) in recip. latt. units, and wts, for input to pw program'')') nkvec
        do 22 k=1,ndim
          rkvec_latt(k)=0
          do 22 i=1,ndim
   22       rkvec_latt(k)=rkvec_latt(k)+glatt_inv(k,i)*rkvec(i,ikv)
        write(6,'(''k-vec('',i2,'')='',3f14.10,f4.0)') ikv,(rkvec_latt(k),k=1,ndim),dfloat(k_inv(ikv))

! If k is half a primitive-cell lattice vector then k_inv=1, else it is 2.
        rknorm(ikv)=0
        k_inv(ikv)=1
        do 23 k=1,ndim
          if(abs(rkvec_latt(k)-.5d0*nint(2*rkvec_latt(k))).gt.1.d-12) k_inv(ikv)=2
   23     rknorm(ikv)=rknorm(ikv)+rkvec(k,ikv)**2
        rknorm(ikv)=sqrt(rknorm(ikv))

! Figure out k-vector in reciprocal simulation-cell lattice vector units with k-shift removed
        write(6,'(/,i2,'' k-vectors (unshifted) in recip. simul. cell latt. units'')') nkvec
        do 25 k=1,ndim
   25     rkvec_tmp(k)=rkvec(k,ikv)-rkvec_shift(k)
        do 28 k=1,ndim
          rkvec_latt(k)=0
          do 26 i=1,ndim
   26       rkvec_latt(k)=rkvec_latt(k)+glatt_sim_inv(k,i)*rkvec_tmp(i)
          if(abs(rkvec_latt(k)-nint(rkvec_latt(k))).gt.1.d-12) then
            write(6,'(''k-vec('',i2,'')='',3f14.10)') ikv,rkvec_latt(k)
            write(6,'(''unshifted k-vector is not a integer in recip. simul. cell latt. units. Possibly the k-vector shifts in the &
      &input and the orbitals file do not match'')')
            stop 'unshifted k-vector is not a integer in recip. simul. cell latt. units. Possibly the k-vector shifts in the &
      &input and the orbitals file do not match'
          endif
   28   kvec(k,ikv)=nint(rkvec_latt(k))
        write(6,'(''k-vec('',i2,'')='',3f14.10)') ikv,(rkvec_latt(k),k=1,ndim)

! I map iwgvec(j)=j in order to keep most of the code the same for orbitals read from TM and other PW codes.
!       read(30,*) (iwgvec(j),j=1,ngvec_dftorb)
        call alloc ('iwgvec', iwgvec, ngvec_dftorb)
        do j=1,ngvec_dftorb
          iwgvec(j)=j
        enddo


! Establish the mapping between DFT and QMC g-vectors.
! Note that the DFT g-vectors for each k-pt are different and are themselves mapped
! to the list of gvectors at beginning of orbitals_pw_tm file but not for orbitals_pw_pwscf
        call alloc ('map_gvecdft_gvec', map_gvecdft_gvec, ngvec_dftorb)
        call alloc ('isign_gvecdft_gvec', isign_gvecdft_gvec, ngvec_dftorb)
        ngvec_found=0
        do 35 igv=1,ngvec
          if(igvec(1,igv).eq.0 .and. igvec(2,igv).eq.0 .and. igvec(3,igv).eq.0) then
            isign_min=1
           else
            isign_min=-1
          endif
          do 32 ig=1,ngvec_dftorb
            do 32 isign=1,isign_min,-2
              norm=0
!             write(6,*) (igvec_dft(k,iwgvec(ig)),k=1,ndim),(igvec(k,igv),k=1,ndim)
              do 30 k=1,ndim
   30           norm=norm+(igvec_dft(k,iwgvec(ig))-isign*igvec(k,igv))**2

              if(norm.eq.0) then
                ngvec_found=ngvec_found+1
                ngvec_orb=max(ngvec_orb,igv)
                map_gvecdft_gvec(ig)=igv
                isign_gvecdft_gvec(ig)=isign
!               write(6,'(''igv,ig,isign,ngvec_found'',9i5)') igv,ig,isign,ngvec_found
              endif
   32     continue
!         write(6,'(''igv,jorb,c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb)'',2i5,9d12.4)')
!    & igv,jorb,c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb)
   35   continue

        if(ngvec_found.ne.ngvec_dftorb) then
          write(6,'(''ngvec_dftorb,ngvec_found='',2i5)') ngvec_dftorb,ngvec_found
          if(ipr.ge.1 .and. (index(mode,'mpi').eq.0 .or. idtask.eq.0)) &
     &    write(3,'(''ngvec_dftorb,ngvec_found='',2i5)') ngvec_dftorb,ngvec_found
          if(ngvec_found.lt.ngvec_dftorb) then
             write(6,'(''Increase cutg to about'',f6.2,'' or more'')') cutg*(dfloat(ngvec_dftorb)/ngvec_found)**(1.d0/3.d0)
             stop 'probably need to increase cutg to generate more g-vectors'
          endif
          stop 'ngvec_found != ngvec_dftorb in read_orb_pw_pwscf'
        endif

        nband_tmp=0
        write(6,*)'ngvec_dftorb=',ngvec_dftorb
        do 80 iband=1,nband(ikv)
          iorba=iorba+k_inv(ikv)
          if(iorba > norb) then
             call alloc ('iflag', iflag, iorba)
             iflag(norb+1:iorba)=0
          endif
!JT          if(iorba.gt.MORB) stop 'iorba>MORB in read_orb_pw_tm'
          morb = max (morb, iorba) !JT
          read(30,*)
          write(6,*) 'Skipped "Band, spin, eigenvalue (au)" line'
          read(30,*) ibandx,ispin,eig
          write(6,'(''ibandx,ispin,eig='',2i4,f10.6)') ibandx,ispin,eig
          read(30,*)
          write(6,*) 'Skipped "Eigenvector coefficients" line'
! I am commenting out the next line because pwscf numbers the band index separately for up and down spins, when the orbitals for these are not the same.
!         if(ibandx.ne.iband) stop 'ibandx.ne.iband in read_orb_pw_pwscf'
          if(ispin.ne.1 .and. ispin.ne.2) stop 'ispin.ne.1 or 2 in read_orb_pw_pwscf'
          call alloc ('c_real', c_real, ngvec_dftorb)
          if(icmplx.ne.0) then
            call alloc ('c_imag', c_imag, ngvec_dftorb)
            do ig=1,ngvec_dftorb
               read(30,*) c_complex_tmp
!              write(6,*) ig,c_complex_tmp
               c_real(ig)=real(c_complex_tmp)
               c_imag(ig)=aimag(c_complex_tmp)
            enddo
           else
            read(30,*) (c_real(ig),ig=1,ngvec_dftorb)
          endif

! eigmin is the energy of the lowest unocc. orb, eigmax that of the highest occ. one.
! I have replaced lines below with double 'if' lines because if we do not then
! (iorba-1) may be 0 when k_inv(ikv).eq.1 and accessing iflag(0) is illegal.
!         if(k_inv(ikv).eq.2.and.iflag(iorba-1).ne.iflag(iorba)) stop
!    &    'if k_inv=2 then the 2 indep. states should have same occupancy
!    &    (except for some excited states)'
!         if((k_inv(ikv).eq.1.and.iflag(iorba).eq.0) .or.
!    &    (k_inv(ikv).eq.2.and.iflag(iorba-1).eq.0.and.iflag(iorba).eq.0)) then
!           eigmin=min(eigmin,eig)
!           goto 80
!         endif
          if(k_inv(ikv).eq.2) then
            if(iflag(iorba-1).ne.iflag(iorba)) then
              write(6,'(''ikv,k_inv(ikv),iband,iorba,eig='',4i5,9f9.5)') ikv,k_inv(ikv),iband,iorba,eig
              stop 'if k_inv=2 then the 2 indep. states should have same occupancy (except for some excited states). &
     & Likely reason is iworbd is incorrect'
            endif
          endif
          if(k_inv(ikv).eq.1.and.iflag(iorba).eq.0) then
            eigmin=min(eigmin,eig)
            goto 80
          endif
          if(k_inv(ikv).eq.2) then
            if(iflag(iorba-1).eq.0.and.iflag(iorba).eq.0) then
              eigmin=min(eigmin,eig)
              goto 80
            endif
          endif

          eigmax=max(eigmax,eig)
          jorb=jorb+1
          jorba=jorba+k_inv(ikv)
!JT          if(jorba.gt.MORB_OCC) stop 'jorba > MORB_OCC in read_orb_pw_pwscf'
          morb = max (morb, jorba+1) !JT
          nband_tmp=nband_tmp+1

! If there is only one linearly indep. state formed from psi_k and psi_-k then
! determine if that state is real or imaginary.  This is possibly not reliable
! so redo it later using values of orbitals at some point.
          if(k_inv(ikv).eq.1) then
            if(rknorm(ikv).eq.0.d0) then
              ig_min=2
             else
              ig_min=1
            endif
            sum=0
            sum_abs=0
            do 40 ig=ig_min,ngvec_dftorb
              sum=sum+c_real(ig)
   40         sum_abs=sum_abs+abs(c_real(ig))
            if(abs(sum/sum_abs).gt.1.d-6) then
              ireal_imag(jorba)=1
             else
              ireal_imag(jorba)=2
            endif
            if(ipr.ge.1) write(6,'(''ikv,iband,ireal_imag,sum,sum_abs='',3i4,9d12.4)') &
     &      ikv,iband,ireal_imag(jorba),sum,sum_abs
           else
            ireal_imag(jorba-1)=0
            ireal_imag(jorba)=0
          endif

! Set ngvec of them to 0 because we do not know until we have processed all k-pts
! what the final value of ngvec_orb will be, and ngvec is an upper bound to ngvec_orb.
          call alloc ('c_rp', c_rp, ngvec, jorb)
          call alloc ('c_rm', c_rm, ngvec, jorb)
          call alloc ('c_ip', c_ip, ngvec, jorb)
          call alloc ('c_im', c_im, ngvec, jorb)
          do 45 igv=1,ngvec
            c_rp(igv,jorb)=0
            c_rm(igv,jorb)=0
            c_ip(igv,jorb)=0
   45       c_im(igv,jorb)=0

          do 50 ig=1,ngvec_dftorb
            igv=map_gvecdft_gvec(ig)
            isign=isign_gvecdft_gvec(ig)
            c_rp(igv,jorb)=c_rp(igv,jorb)+c_real(ig)
            c_rm(igv,jorb)=c_rm(igv,jorb)+c_real(ig)*isign
            c_ip(igv,jorb)=c_ip(igv,jorb)+c_imag(ig)
   50       c_im(igv,jorb)=c_im(igv,jorb)+c_imag(ig)*isign
!           write(6,'(''igv,jorb,c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb)'',2i5,9d12.4)')
!    & igv,jorb,c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb)

          do 60 igv=1,ngvec_dft
            c_rp(igv,jorb)=rnorm*c_rp(igv,jorb)
            c_rm(igv,jorb)=rnorm*c_rm(igv,jorb)
            c_ip(igv,jorb)=rnorm*c_ip(igv,jorb)
   60       c_im(igv,jorb)=rnorm*c_im(igv,jorb)
!         call my_second(2,'42    ')

          if(ipr.ge.1 .and. (index(mode,'mpi').eq.0 .or. idtask.eq.0)) write(3,'(i5,f10.6,'' iband, eig (Ha)'')') iband,eig
          if(ipr.ge.0) write(6,'(i5,f10.6,'' iband, eig (Ha)'')') iband,eig
          if(ipr.ge.1 .and. (index(mode,'mpi').eq.0 .or. idtask.eq.0)) then
            if(k_inv(ikv).eq.1 ) then
              write(3,'(1p2d22.14)') (c_rp(igv,jorb),c_rm(igv,jorb),igv=1,ngvec)
             else
              write(3,'(1p4d22.14)') (c_rp(igv,jorb),c_rm(igv,jorb),c_ip(igv,jorb),c_im(igv,jorb),igv=1,ngvec)
            endif
          endif

! We calculate orbitals dumb way and then smart way so that they can be compared
! by eye to make sure smart way is right.
! Calculation of orbitals dumb way with orbitals_pw2 is time consuming.
! Also, choose which state to keep when there is only one independent state (k=G/2)
!     call my_second(1,'orb_s1')
! Test to see if orbitals and derivs. calculated correctly
          call orbitals_pw2(ikv,iband,jorba)
! If there is only 1 independent state, choose it to be the one with the largest absolute value
! unless it is linearly dependent on an already chosen state
! If there is only 1 independent state, choose it to be the one with the largest absolute value
! unless it is linearly dependent on an already chosen state.  To check for linear dependence check both the ratio of
! the laplacian to the orbital and the first gradient component to the orbital to avoid a match by chance.
          if(k_inv(ikv).eq.1) then
            if(jorba.ge.2) then
              if(abs(orb_si(jorba+1)*ddorb_si(jorba-1)/(orb_si(jorba-1)*ddorb_si(jorba+1))-1).lt.eps .and. &
     &           abs(orb_si(jorba+1)*dorb_si(1,jorba-1)/(orb_si(jorba-1)*dorb_si(1,jorba+1))-1).lt.eps) then
                ireal_imag(jorba)=1
                goto 70
              endif
              if(abs(orb_si(jorba)*ddorb_si(jorba-1)/(orb_si(jorba-1)*ddorb_si(jorba))-1).lt.eps .and. &
     &           abs(orb_si(jorba)*dorb_si(1,jorba-1)/(orb_si(jorba-1)*dorb_si(1,jorba))-1).lt.eps) then
                ireal_imag(jorba)=2
                goto 70
              endif
            endif
            if(jorba.ge.3) then
              if(abs(orb_si(jorba+1)*ddorb_si(jorba-2)/(orb_si(jorba-2)*ddorb_si(jorba+1))-1).lt.eps .and. &
     &           abs(orb_si(jorba+1)*dorb_si(1,jorba-2)/(orb_si(jorba-2)*dorb_si(1,jorba+1))-1).lt.eps) then
                ireal_imag(jorba)=1
                goto 70
              endif
              if(abs(orb_si(jorba)*ddorb_si(jorba-2)/(orb_si(jorba-2)*ddorb_si(jorba))-1).lt.eps .and. &
     &           abs(orb_si(jorba)*dorb_si(1,jorba-2)/(orb_si(jorba-2)*dorb_si(1,jorba))-1).lt.eps) then
                ireal_imag(jorba)=2
                goto 70
              endif
            endif
            if(abs(orb_si(jorba)/orb_si(jorba+1)).gt.1.d0) then
              ireal_imag(jorba)=1
             else
              ireal_imag(jorba)=2
            endif

   70       if(ireal_imag(jorba).eq.1) then
              write(6,'(''iband,ireal_imag,orb_simple='',i3,i2,5d15.8)') &
     &        iband,ireal_imag(jorba),orb_si(jorba),ddorb_si(jorba),(dorb_si(k,jorba),k=1,ndim)
! Warning: tmp
              write(6,'(''iband,           orb_simple='',i3,2x, 5d15.8)') &
     &        iband,orb_si(jorba+1),ddorb_si(jorba+1),(dorb_si(k,jorba+1),k=1,ndim)
             else
! Warning: tmp
              write(6,'(''iband,           orb_simple='',i3,2x, 5d15.8)') &
     &        iband,orb_si(jorba),ddorb_si(jorba),(dorb_si(k,jorba),k=1,ndim)

              write(6,'(''iband,ireal_imag,orb_simple='',i3,i2,5d15.8)') &
     &        iband,ireal_imag(jorba),orb_si(jorba+1),ddorb_si(jorba+1),(dorb_si(k,jorba+1),k=1,ndim)
! Save the orb_si and 2nd deriv in order to check for linear dependency
              orb_si(jorba)=orb_si(jorba+1)
              ddorb_si(jorba)=ddorb_si(jorba+1)
              do  k=1,ndim
                dorb_si(k,jorba)=dorb_si(k,jorba+1)
              enddo
            endif
           else
            ireal_imag(jorba-1)=0
            ireal_imag(jorba)=0
            write(6,'(''iband,ireal_imag,orb_simple='',i3,i2,5d15.8)') &
     &      iband,ireal_imag(jorba-1),orb_si(jorba-1),ddorb_si(jorba-1),(dorb_si(k,jorba-1),k=1,ndim)
            write(6,'(''iband,ireal_imag,orb_simple='',i3,i2,5d15.8)') &
     &      iband,ireal_imag(jorba),orb_si(jorba),ddorb_si(jorba),(dorb_si(k,jorba),k=1,ndim)
          endif

   80   continue
   90   nband(ikv)=nband_tmp
      call my_second(2,'orb_si')

      write(6,'(2i4,'' orbitals read in from file orbitals_pw_pwscf'')') jorb,jorba
      if(jorba.lt.norb) then
        write(6,'(''jorba,norb='',2i5)') jorba,norb
        stop 'jorba < norb in read_orb_pw_pwscf'
      endif

      write(6,'(/,''energy of highest  occupied orbital='',f10.6)') eigmax
      if(eigmin.ne.1.d99) then
        write(6,'(''energy of lowest unoccupied orbital='',f10.6)') eigmin
       else
        write(6,'(''no unoccupied orbitals'')')
      endif
      if(eigmin.lt.eigmax) write(6,'(''Warning: Energy of lowest unoccupied &
     &orbital is lower than that of the highest occupied one.'',/, &
     &''This may be because you are calculating an excited state, or it may be &
      &that you are calculating a ground state but the single particle'',/, &
     &''band structure has a band overlap, though in fact there is none.'')')

      close(30)
      return

  999 write(6,'(''Error: file orbitals_pw_pwscf is missing'')')
      stop 'file orbitals_pw_pwscf is missing'
      end
!-----------------------------------------------------------------------
      subroutine orbitals_pw2(ikv,iband,jorba)
! Written by Cyrus Umrigar
! Calculate pw orbitals.
! isortg could be (but is not) used to map g-vectors from iv to ig.
! At present it is assumed that k-vectors are in the correct order, but
! if not one could use isortk to map iorb.
! Note: This is the straightforward, expensive evaluation for checking purposes only.

      use basic_tools_mod, only: alloc
      use tempor_test_mod
      use const_mod
      use dim_mod
      use periodic_mod
      use coefs_mod
      implicit real*8(a-h,o-z)


!1    dimension r(3),orb(MELEC,*),dorb(3,MELEC,*),ddorb(MELEC,*)
!     dimension dcos_rp(3),dsin_rm(3),dcos_ip(3),dsin_im(3)
!    &,cos_g(MELEC,NGVECX),sin_g(MELEC,NGVECX),dcos_g(3,MELEC,NGVECX),dsin_g(3,MELEC,NGVECX)
!    &,ddcos_g(MELEC,NGVECX),ddsin_g(MELEC,NGVECX)
!    &,cos_k(MELEC,MKPTS),sin_k(MELEC,MKPTS),dcos_k(3,MELEC,MKPTS),dsin_k(3,MELEC,MKPTS)
!    &,ddcos_k(MELEC,MKPTS),ddsin_k(MELEC,MKPTS)
      dimension gvec_dft(3,ngvec_dft),gnorm_dft(ngvec_dft)

!     write(6,'(''nelec,norb,nkvec in orbitals_pw2'',9i5)') nelec,norb,nkvec

      do 26 ig=1,ngvec_dft
        do 23 k=1,ndim
          gvec_dft(k,ig)=0
          do 23 i=1,ndim
   23       gvec_dft(k,ig)=gvec_dft(k,ig)+igvec_dft(i,ig)*glatt(k,i)
!       write(6,'(/,''igvec_dft in recip. lat. vec. units'',9i4)') (igvec_dft(i,ig),i=1,ndim)
!  26   write(6,'(''gvec_dft in cartesian coodinates'',9f9.4)') (gvec_dft(k,ig),k=1,ndim)
   26 continue

      if(ipr.ge.1) then
        if(ikv.eq.1.and.iband.eq.1) then
          open(4,file='wf_alfe')
          write(4,'(i5,'' g-vectors are:'')') ngg(ikv)
! Warning this may not work if there is more than one k-vec because ngg(ikv) may be larger than ngg(1).
          write(4,'(3f19.15)') ((gvec_dft(k,iwgvec(ig)),k=1,ndim),ig=1,ngg(ikv))
        endif
        if(ikv.eq.1) write(4,'(''k-vector is'',3f12.8)') (rkvec(k,ikv),k=1,ndim)
        write(4,'(''iband='',i5)') iband
        write(4,'(1p2g23.15)') (c_real(ig),c_imag(ig),ig=1,ngg(ikv))
      endif

! Warning: c_real and c_imag are only stored for particular k-vector and band
! Warning: for the moment just use this for testing 1 electron
!1    nelecc=1
!1    do 80 i=1,nelecc
!     iorb=0
!     do 80 ikv=1,nkvec
!       do 80 iband=1,nband(ikv)

        iorb=jorba-k_inv(ikv)
! Calculate psi_+ orbital if that is the one kept or if both are kept
!       if(ireal_imag(iorb).eq.0 .or. ireal_imag(iorb).eq.1) then

        iorb=iorb+1
        call alloc ('orb_si', orb_si, morb)
        call alloc ('dorb_si', dorb_si, 3, morb)
        call alloc ('ddorb_si', ddorb_si, morb)
        orb_si(iorb)=0
        ddorb_si(iorb)=0
        do 29 k=1,ndim
   29     dorb_si(k,iorb)=0
        do 40 ig=1,ngg(ikv)
          ig2=iwgvec(ig)
          dot=0
          gnorm_dft(ig2)=0
          do 30 k=1,ndim
            gnorm_dft(ig2)=gnorm_dft(ig2)+(rkvec(k,ikv)+gvec_dft(k,ig2))**2
   30       dot=dot+(rkvec(k,ikv)+gvec_dft(k,ig2))*r(k)
          orb_si(iorb)=orb_si(iorb)+c_real(ig)*cos(dot)-c_imag(ig)*sin(dot)
          if(ipr.ge.4 .and. ig.le.22) write(6,'(''rkvec+gvec'',2i4,7f9.4,f18.12)') &
     &    ig,ig2,(rkvec(k,ikv)+gvec_dft(k,ig2),k=1,ndim),c_real(ig),dot,cos(dot),sin(dot),orb_si(iorb)
          do 35 k=1,ndim
   35       dorb_si(k,iorb)=dorb_si(k,iorb)+(rkvec(k,ikv)+gvec_dft(k,ig2))*(-c_real(ig)*sin(dot)-c_imag(ig)*cos(dot))
   40     ddorb_si(iorb)=ddorb_si(iorb)-gnorm_dft(ig2)*(c_real(ig)*cos(dot)-c_imag(ig)*sin(dot))

        orb_si(iorb)=orb_si(iorb)*rnorm
        ddorb_si(iorb)=ddorb_si(iorb)*rnorm
        do 55 k=1,ndim
   55      dorb_si(k,iorb)=dorb_si(k,iorb)*rnorm

!       write(6,'(''ikv,iband,nband(ikv),k_inv(ikv)'',9i5)') ikv,iband,nband(ikv),k_inv(ikv)
!       write(6,'(''real orb_si='',i5,9d12.4)') iorb,orb_si(iorb)
!       endif

! Calculate psi_- orbital if that is the one kept or if both are kept
!       if(ireal_imag(iorb).eq.0 .or. ireal_imag(iorb).eq.2) then

        iorb=iorb+1
! This routine is just used for testing and the dimensioning is such that
! if norb=MORB then iorb could be MORB+1, because even if one is kept, both are
! calculated in order to decide which to keep.  So do the foll. check:
!JT        if(iorb.gt.MORB) then
!JT          write(6,*)'iorb,MORB=',iorb,morb
!JT          stop 'iorb>MORB in orbitals_pw2'
!JT        endif

        orb_si(iorb)=0
        ddorb_si(iorb)=0
        do 59 k=1,ndim
   59     dorb_si(k,iorb)=0
        do 70 ig=1,ngg(ikv)
          ig2=iwgvec(ig)
          dot=0
          gnorm_dft(ig2)=0
          do 60 k=1,ndim
            gnorm_dft(ig2)=gnorm_dft(ig2)+(rkvec(k,ikv)+gvec_dft(k,ig2))**2
   60       dot=dot+(rkvec(k,ikv)+gvec_dft(k,ig2))*r(k)
          orb_si(iorb)=orb_si(iorb)+c_real(ig)*sin(dot)+c_imag(ig)*cos(dot)
!         if(ipr.ge.4 .and. ig.le.22) write(6,'(''rkvec+gvec'',2i4,7f9.4,f18.12)')
!    &    ig,ig2,(rkvec(k,ikv)+gvec_dft(k,ig2),k=1,ndim),c_real(ig),dot,cos(dot),sin(dot),orb_si(iorb)
          if(ipr.ge.4 .and. ig.le.22) write(6,'(''rkvec,gvec'',8f9.4)') (rkvec(k,ikv),gvec_dft(k,ig2),k=1,ndim)
          if(ipr.ge.4 .and. ig.le.22) write(6,'(''rkvec+gvec'',2i4,8f9.4,f18.12)') &
     &    ig,ig2,(rkvec(k,ikv)+gvec_dft(k,ig2),k=1,ndim),c_real(ig),r(1),dot,cos(dot),sin(dot),orb_si(iorb)
          do 65 k=1,ndim
   65       dorb_si(k,iorb)=dorb_si(k,iorb)+(rkvec(k,ikv)+gvec_dft(k,ig2))*(c_real(ig)*cos(dot)-c_imag(ig)*sin(dot))
   70     ddorb_si(iorb)=ddorb_si(iorb)-gnorm_dft(ig2)*(c_real(ig)*sin(dot)+c_imag(ig)*cos(dot))

        orb_si(iorb)=orb_si(iorb)*rnorm
        ddorb_si(iorb)=ddorb_si(iorb)*rnorm
        do 75 k=1,ndim
   75      dorb_si(k,iorb)=dorb_si(k,iorb)*rnorm

!       write(6,'(''ikv,iband,nband(ikv),k_inv(ikv)'',9i5)') ikv,iband,nband(ikv),k_inv(ikv)
!       write(6,'(''imag orb_si='',i5,9d12.4)') iorb,orb_si(iorb)

!       endif
!       endif

!  80   continue

      return
      end
!-----------------------------------------------------------------------
      subroutine print_orbitals_pw

      use bwfdet_mod
      use bsplines_mod
      use orbital_grid_mod
      use dorb_mod
      use coefs_mod
      use dets_mod
      use const_mod
      use dim_mod
      use contr2_mod
      use contr3_mod
      use periodic_mod
      use contr_names_mod
      use periodic2_mod
      implicit real*8(a-h,o-z)

      parameter(eps=1.d-3)

      dimension r(3),r_basis(3),r_test(3,ngrid_orbx*ngrid_orby*ngrid_orbz)
      dimension orb(norb),dorb(3,norb),ddorb(norb)
!     dimension orb_splines_tmp(10),ict(10),ddorb_splines_tmp(3)
      dimension orb_tmp(norb),dorb_tmp(3,norb), &
     &          ddorb_tmp(norb)
      dimension orb_blip_tmp(norb,ndet), &
     &          dorb_blip_tmp(3,norb,ndet), &
     &          ddorb_blip_tmp(norb,ndet)


      integer i,k,ix,iy,iz,iorb,ier,isgn,npts,npts_max,xfac,yfac,zfac

      write(6,'(''Entering print_orbitals_pw'')')

!     ngrid_orbx=MGRID_ORB_PER
!     ngrid_orby=MGRID_ORB_PER
!     ngrid_orbz=MGRID_ORB_PER

      open(14,file='print_orbitals.data')
      read(14,*)npts,xfac,yfac,zfac
      close(14)
      write(6,*)'Read print_orbitals.data with ',npts,' points in the ',xfac,' ',yfac,' ',zfac,' direction'

      npts_max=ngrid_orbx*ngrid_orby*ngrid_orbz

      if(npts.gt.npts_max) stop 'npts must be less than ngrid_orbx*ngrid_orby*ngrid_orbz'

      if(xfac.ne.0) then
         do i=0,npts-1
            r_test(1,i)=i/dfloat(npts-1)
            r_test(2,i)=r_test(1,i)*dfloat(yfac)/dfloat(xfac)
            r_test(3,i)=r_test(1,i)*dfloat(zfac)/dfloat(xfac)
         enddo
      elseif(yfac.ne.0) then
         do iy=0,npts-1
            r_test(1,i)=0.d0
            r_test(2,i)=iy/dfloat(npts-1)
            r_test(3,i)=r_test(2,i)*dfloat(zfac)/dfloat(yfac)
         enddo
      elseif(zfac.ne.0) then
         do iz=0,npts-1
            r_test(1,i)=0.d0
            r_test(2,i)=0.d0
            r_test(3,i)=i/dfloat(npts-1)
         enddo
      else
         stop '000 is not a valid direction'
      endif

! File open
      if(inum_orb.eq.0) then
          open(15,file='pw_test.data')
          write(15,*)'#',npts,'points'
          write(15,*)'#',xfac,yfac,zfac,' direction'
      endif
      if(inum_orb.eq.4 .or. inum_orb.eq.-4) then
          open(15,file='lagrange_test.data')
          write(15,*)'#',npts,'points'
          write(15,*)'#',xfac,yfac,zfac,' direction'
      endif
      if(inum_orb.eq.6 .or. inum_orb.eq.-6) then
          open(15,file='blip_test.data')
          write(15,*)'#',npts,'points'
          write(15,*)'#',xfac,yfac,zfac,' direction'
      endif

      if(inum_orb.eq.8 .or. inum_orb.eq.-8) then
          open(15,file='bspline_test.data')
          write(15,*)'#',npts,'points'
          write(15,*)'#',xfac,yfac,zfac,' direction'
      endif

      do ix=0,npts-1
         r_basis(1)=r_test(1,ix)
         r_basis(2)=r_test(2,ix)
         r_basis(3)=r_test(3,ix)

!        do ix=0,2*(ngrid_orbx)*(ngrid_orbx-1)-2
!           r_basis(1)=ix/dfloat(2*(ngrid_orbx)*(ngrid_orbx-1)-2)

!           do iy=0,2*(ngrid_orby)*(ngrid_orby-1)-2
!             r_basis(2)=iy/dfloat(2*(ngrid_orby)*(ngrid_orby-1)-2)

!              do iz=0,2*(ngrid_orbz)*(ngrid_orbz-1)-2
!                r_basis(3)=iz/dfloat(2*(ngrid_orbz)*(ngrid_orbz-1)-2)

                 isgn=1
                 do k=1,ndim
                   if(rkvec_shift_latt(k).ne.0.d0) then
                     if(r_basis(k).ge.0.d0) then
                       isgn=isgn*(-1)**int(r_basis(k))
                      else
                       isgn=isgn*(-1)**(int(r_basis(k))+1)
                     endif
                   endif
                 enddo

!wparker Go along the <100> direction
!                if (iy.eq.0 .and. iz.eq.0) then
!wparker Go along the <010> direction
!                if (ix.eq.0 .and. iz.eq.0) then
!wparker Go along the <001> direction
!                if (ix.eq.0 .and. iy.eq.0) then
!wparker Go along the <110> direction
!                if (ix.eq.iy .and. iz.eq.0) then
!wparker Go along the <111> direction
!                if (ix.eq.iy .and. iy.eq.iz) then

                    do k=1,ndim
                       r(k)=0
                       do i=1,ndim
                          r(k)=r(k)+rlatt_sim(k,i)*r_basis(i)
                       enddo
                    enddo

!wparker Plane wave printout
                 if(inum_orb.eq.0) then

                   call orbitals_pw_grade(r,orb,dorb,ddorb)
                   do iorb=1,norb
                      if(xfac.ne.0) then
!wparker write statement for xyz directions
                       write(15,'(''r(1),orb('',i2,''),dorb('',i2,''),'' &
     &                   ,''ddorb('',i2,'')='',6f14.8)')iorb,iorb,iorb, &
     &                   r_basis(1),orb(iorb),dorb(1,iorb),dorb(2,iorb), &
     &                   dorb(3,iorb),ddorb(iorb)
                      elseif(yfac.ne.0) then
!wparker write statement for 0yz directions
                       write(15,'(''r(2),orb('',i2,''),dorb('',i2,''),'' &
     &                   ,''ddorb('',i2,'')='',6f14.8)')iorb,iorb,iorb, &
     &                   r_basis(2),orb(iorb),dorb(1,iorb),dorb(2,iorb), &
     &                   dorb(3,iorb),ddorb(iorb)
                      elseif(zfac.ne.0) then
!wparker write statement for 00z directions
                       write(15,'(''r(3),orb('',i2,''),dorb('',i2,''),'' &
     &                   ,''ddorb('',i2,'')='',6f14.8)')iorb,iorb,iorb, &
     &                   r_basis(3),orb(iorb),dorb(1,iorb),dorb(2,iorb), &
     &                   dorb(3,iorb),ddorb(iorb)
                      endif
                   enddo
                 endif
!wparker End of plane wave printout

!wparker Lagrange polynomial printout
                 if(inum_orb.eq.4 .or. inum_orb.eq.-4) then
                   xi=r_basis(1)*ngrid_orbx
                   yi=r_basis(2)*ngrid_orby
                   zi=r_basis(3)*ngrid_orbz

                   call interpol_orb(ngrid_orbx,ngrid_orby,ngrid_orbz, &
     &               xi,yi,zi,orb_tmp,dorb_tmp,ddorb_tmp)

                   do iorb=1,norb
                      if(xfac.ne.0) then
!wparker write statement for xyz directions
                        write(15,'(''r(1),orb('',i2,''),dorb('',i2,''), &
     &ddorb('',i2,'')='',6f14.8)')iorb,iorb,iorb,r_basis(1), &
     &isgn*orb_tmp(iorb),isgn*dorb_tmp(1,iorb),isgn*dorb_tmp(2,iorb), &
     &isgn*dorb_tmp(3,iorb),isgn*ddorb_tmp(iorb)
!wparker write statement for 0yz directions
                      elseif(yfac.ne.0) then
                        write(15,'(''r(2),orb('',i2,''),dorb('',i2,''), &
     &ddorb('',i2,'')='',6f14.8)')iorb,iorb,iorb,r_basis(2), &
     &isgn*orb_tmp(iorb),isgn*dorb_tmp(1,iorb),isgn*dorb_tmp(2,iorb), &
     &isgn*dorb_tmp(3,iorb),isgn*ddorb_tmp(iorb)
!wparker write statement for 00z directions
                      elseif(zfac.ne.0) then
                        write(15,'(''r(3),orb('',i2,''),dorb('',i2,''), &
     &ddorb('',i2,'')='',6f14.8)')iorb,iorb,iorb,r_basis(3), &
     &isgn*orb_tmp(iorb),isgn*dorb_tmp(1,iorb),isgn*dorb_tmp(2,iorb), &
     &isgn*dorb_tmp(3,iorb),isgn*ddorb_tmp(iorb)
                      endif
                   enddo
                 endif
!wparker End of Lagrange polynomial printout

!wparker Blip printout
                 if(inum_orb.eq.6 .or. inum_orb.eq.-6) then
                    call bwfdet_main(r,1,1,1,orb_blip_tmp, &
     &                               dorb_blip_tmp,ddorb_blip_tmp)

                   do iorb=1,norb
                      if(xfac.ne.0) then
!wparker write statement for 1yz directions
                        write(15,'(''r(1),orb('',i2,''),dorb('',i2,''), &
     &ddorb('',i2,''),'',6f14.8)') iorb,iorb,iorb,r_basis(1), &
     &orb_blip_tmp(iorb,1),dorb_blip_tmp(1,iorb,1), &
     &dorb_blip_tmp(2,iorb,1),dorb_blip_tmp(3,iorb,1), &
     &ddorb_blip_tmp(iorb,1)
                      elseif(yfac.ne.0) then
!wparker write statement for x1z directions
                        write(15,'(''r(2),orb('',i2,''),dorb('',i2,''), &
     &ddorb('',i2,''),'',6f14.8)') iorb,iorb,iorb,r_basis(2), &
     &orb_blip_tmp(iorb,1),dorb_blip_tmp(1,iorb,1), &
     &dorb_blip_tmp(2,iorb,1),dorb_blip_tmp(3,iorb,1), &
     &ddorb_blip_tmp(iorb,1)
                      elseif(zfac.ne.0) then
!wparker write statement for xy1 directions
                        write(15,'(''r(3),orb('',i2,''),dorb('',i2,''), &
     &ddorb('',i2,''),'',6f14.8)') iorb,iorb,iorb,r_basis(3), &
     &orb_blip_tmp(iorb,1),dorb_blip_tmp(1,iorb,1), &
     &dorb_blip_tmp(2,iorb,1),dorb_blip_tmp(3,iorb,1), &
     &ddorb_blip_tmp(iorb,1)
                      endif
                   enddo
                 endif
!wparker End of blip printout
!wparker Interpolating B-Spline printout
                 if(inum_orb.eq.8 .or. inum_orb.eq.-8) then

#ifdef NOEINSPLINE
                    write(6,*) 'the code must be linked to einspline library'
                    stop 'the code must be linked to einspline library'
#else
                    call evaluate_bsplines_with_derivatives(r,orb_tmp,dorb_tmp,ddorb_tmp)
#endif
                    do iorb=1,norb

                      if(xfac.ne.0) then
!wparker write statement for xyz directions
                        write(15,'(''r(1),orb('',i2,''),dorb('',i2,''), &
     &ddorb('',i2,'')= '',6f20.8)')iorb,iorb,iorb,r_basis(1), &
     &orb_tmp(iorb),dorb_tmp(1,iorb),dorb_tmp(2,iorb), &
     &dorb_tmp(3,iorb),ddorb_tmp(iorb)
                      elseif(yfac.ne.0) then
!wparker write statement for 0yz directions
                        write(15,'(''r(2),orb('',i2,''),dorb('',i2,''), &
     &ddorb('',i2,'')= '',6f20.8)')iorb,iorb,iorb,r_basis(2), &
     &orb_tmp(iorb),dorb_tmp(1,iorb),dorb_tmp(2,iorb), &
     &dorb_tmp(3,iorb),ddorb_tmp(iorb)
                      elseif(zfac.ne.0) then
!wparker write statement for 00z directions
                        write(15,'(''r(3),orb('',i2,''),dorb('',i2,''), &
     &ddorb('',i2,'')= '',6f20.8)')iorb,iorb,iorb,r_basis(3), &
     &orb_tmp(iorb),dorb_tmp(1,iorb),dorb_tmp(2,iorb), &
     &dorb_tmp(3,iorb),ddorb_tmp(iorb)
                      endif

                    enddo

                  endif
!wparker End of interpolating B-Spline printout

!                endif

!wparker End of r_test do loop
         enddo

!wparker End of directional choice (<100>,<010>,<001> or  <110>)
!              enddo
!           enddo
!        enddo
!wparker End of grid do loops

!wparker Close test data file
       close(15)

!wparker Stop with appropriate message
       if(inum_orb.eq.0) then
         stop 'Done with plane wave printout; see pw_test.data'
       endif
       if(inum_orb.eq.4 .or. inum_orb.eq.-4) then
         stop 'Done with Lagrange printout; see lagrange_test.data'
       endif
       if(inum_orb.eq.6 .or. inum_orb.eq.-6) then
         stop 'Done with B-spline printout; see blip_test.data'
       endif
       if(inum_orb.eq.8 .or. inum_orb.eq.-8) then
         stop 'Done with interpolating B-spline printout; see bspline_test.data'
       endif

       stop 'No orbital printout made; inum_orb invalid'

       return
       end

!-----------------------------------------------------------------------
!     subroutine energy_test

!     use dim_mod
!     use const_mod
!     use contr2_mod
!     use contr3_mod
!     use contr_names_mod
!     use dorb_mod
!     use coefs_mod
!     use dets_mod
!     use periodic_mod
!     use periodic2_mod
!     implicit real*8(a-h,o-z)
!     character*20 fmt
!     character*16 mode,iorb_format

!     parameter(eps=1.d-3)

!     dimension r(3),r_basis(3)
!     integer i,k,ix,iy,iz,iorb


!     ngrid_orbx=MGRID_ORB_PER
!     ngrid_orby=MGRID_ORB_PER
!     ngrid_orbz=MGRID_ORB_PER

!     if(inum_orb.eq.0) then
!         open(15,file='pw_energy_test.data')
!     endif
!     if(inum_orb.eq.4 .or. inum_orb.eq.-4) then
!         open(15,file='lagrange_energy_test.data')
!     endif
!     if(inum_orb.eq.6 .or. inum_orb.eq.-6) then
!         open(15,file='blip_energy_test.data')
!     endif

!        do ix=0,2*(ngrid_orbx)*(ngrid_orbx-1)-2
!           r_basis(1)=ix/dfloat(2*(ngrid_orbx)*(ngrid_orbx-1)-2)

!           do iy=0,2*(ngrid_orby)*(ngrid_orby-1)-2
!             r_basis(2)=iy/dfloat(2*(ngrid_orby)*(ngrid_orbx-1)-2)

!              do iz=0,2*(ngrid_orbz)*(ngrid_orbz-1)-2
!                r_basis(3)=iz/dfloat(2*(ngrid_orbz)*(ngrid_orbz-1)-2)

!wparker Go along the <100> direction
!                if (iy.eq.0 .and. iz.eq.0) then
!wparker Go along the <001> direction
!                if (ix.eq.0 .and. iy.eq.0) then
!wparker Go along the <110> direction
!                if (ix.eq.iy .and. iz.eq.0) then
!wparker Go along the <111> direction
!                if (ix.eq.iy .and. iy.eq.iz) then

!                   do k=1,ndim
!                      r(k)=0
!                      do i=1,ndim
!                         r(k)=r(k)+rlatt_sim(k,i)*r_basis(i)
!                      enddo
!                   enddo

!                   call hpsi(r,determinant,jastrow,velocity,div_v,
!    &                        laplacian,potential,eeinteraction,energy,
!    &                        denergy,ifr)
!                   write(15,'(''r(1),E,V='',3f9.4)')
!    &                   r_basis(1),energy,potential

!                endif
!wparker End of directional choice (<100>,<110> or <100>)

!              enddo
!           enddo
!        enddo
!wparker End of grid do loops

!wparker Close test data file
!      close(15)

!wparker Stop with appropriate message
!      if(inum_orb.eq.0) then
!        stop 'done with plane wave test; see pw_energy_test.data'
!      endif
!      if(inum_orb.eq.4 .or. inum_orb.eq.-4) then
!        stop 'done with Lagrange test; see lagrange_energy_test.data'
!      endif
!      if(inum_orb.eq.6 .or. inum_orb.eq.-6) then
!        stop 'done with blip test; see blip_energy_test.data'
!      endif

!      stop 'no test done; inum_orb not valid'

!      return
!      end

