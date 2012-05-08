      subroutine zigzag2d(p,q,xold,xnew,ielec)

c Written by Abhijit Mehta, December 2011
c  Calculates quantities useful for studying zigzag quantum phase
c  transition in rings and wires.  
c  -reduced pair density
c  -"staggered amplitude"
c  xold and xnew are the old and new configurations
c  p and q are the probabilities of accept and reject
c  ielec labels the electron that was moved for 1-electron moves
c  if ielec=0, we are doing an all-electron move.

c  If you want to add a new observable, make sure you change
c    nzzvars in zigzag_mod.f90 (and do a make clean!)
c  You will also need to add a print out line to print_zigzag_vars()
c       below
      use dets_mod
      use const_mod
      use dim_mod
      use contrl_per_mod, only: iperiodic
      use pairden_mod
      use periodic_1d_mod, only: alattice
      use zigzag_mod
      implicit real*8(a-h,o-z)
      logical l_oldneoldsav, l_oldnenewsav
c     common /circularmesh/ delti
      common /circularmesh/ rmin,rmax,rmean,delradi,delti,nmeshr,nmesht,icoosys
      common /dot/ w0,we,bext,emag,emaglz,emagsz,glande,p1,p2,p3,p4,rring
      dimension xold(3,nelec),xnew(3,nelec)
      dimension zztemp2(nelec), ransign(nelec)
      dimension temppos(2),zzterm(nzzvars)
      dimension zzmaglocal_new(nelec),zzmaglocal_old(nelec)
      dimension zzcorrmat_old(nelec,nelec),zzcorrmat_new(nelec,nelec)

      if(ielec.lt.0 .or. ielec.gt.nelec) then
        write (6,*) 'Bad value of ielec in zigzag2d, ', ielec
        stop "Bad value of ielec in zigzag2d"
      endif

c   zzpos will ultimately hold the sorted electron positions.  The first index labels longitudinal
c      or transverse coordinate (i.e., zzpos(1,nelec) is sorted in ascending order)

c   First, save some sorting work, and see if one of the configurations xnew or xold was already sorted
c    xold_sav and xnew_sav contain the last values of xold and xnew used by this subroutine
c    iold_indices and inew_indices contain the mapping of how the electrons in xold, xnew were sorted
     
      l_oldneoldsav = .false.
      l_oldnenewsav = .false.
      outerloop: do i1 = 1,nelec
        do i2 = 1,2
          if(xold(i2,i1).ne.xold_sav(i2,i1)) then
            l_oldneoldsav = .true.
          endif
          if(xold(i2,i1).ne.xnew_sav(i2,i1)) then
            l_oldnenewsav = .true.
          endif
          if(l_oldneoldsav.and.l_oldnenewsav) exit outerloop 
        enddo
      end do outerloop
      ! if(xold.ne.xold_sav)
      if(l_oldneoldsav) then ! xold has changed
        ! if(xold.eq.xnew_sav)
        if(.not.l_oldnenewsav) then ! The last MC move was accepted, so 'xold' is the old 'xnew'
          zzposold = zzposnew
          iold_indices = inew_indices
        else   ! This branch should probably only happen at the beginning of a block
          if(iperiodic.eq.0) then !rings -> polar coords
            do iering=1,nelec
              zzposold(1,iering) = datan2(xold(2,iering),xold(1,iering)) !theta -> x coordinate
              zzposold(2,iering) = dsqrt(xold(1,iering)**2 + xold(2,iering)**2) ! r -> y coord
            enddo
          elseif(iperiodic.eq.1) then ! wires, keep coords
            zzposold = xold(1:2,:)
          endif
          ! Now, sort zzposold if we can't reuse an already sorted array
          ! iold_indices will contain information on the ordering of electrons in xold
          do i=1,nelec
            iold_indices(i) = i
          enddo
          lognb2 = int(dlog(dfloat(nelec))/dlog(2.D0)+1.D-14)
c   First, we need to sort the electron positions with respect to theta (for rings) or x (for wires)
c   I am using Shell sort for now; it might be more efficient to use something like quicksort or merge sort
c    This implementation of Shell sort is from Cyrus
          M = nelec
          do NN=1,lognb2
            M = M/2
            K = nelec - M
            do J = 1,K
              do I =J,1,-M
                L = I + M
                if(zzposold(1,L).gt.zzposold(1,I)) exit
                temppos = zzposold(:,I)
                itemp = iold_indices(I)
                zzposold(:,I) = zzposold(:,L)
                iold_indices(I) = iold_indices(L)
                zzposold(:,L) = temppos
                iold_indices(L) = itemp
              enddo
            enddo
          enddo
        endif
      endif

c Now, construct zzposnew so that it has about the same order as zzposold

      if(ielec.eq.0) then ! all-electron move; we need to find r and theta 
        if(iperiodic.eq.0) then !rings -> polar coords
          do iering=1,nelec
            ioi = iold_indices(iering)
            zzposnew(1,iering) = datan2(xnew(2,ioi),xnew(1,ioi)) 
            zzposnew(2,iering) = dsqrt(xnew(1,ioi)**2 + xnew(2,ioi)**2)
          enddo
        elseif(iperiodic.eq.1) then ! wires, keep coords
          zzposnew = xnew(1:2,iold_indices)
        endif
      else ! one-electron move
        zzposnew = zzposold ! start by setting new to old, since most of them will be the same
        if(iperiodic.eq.0) then
          temppos(1) = datan2(xnew(2,ielec),xnew(1,ielec))
          temppos(2) = dsqrt(xnew(1,ielec)**2 + xnew(2,ielec)**2)
        elseif(iperiodic.eq.1) then
          temppos = xnew(1:2,ielec)
        endif
        do i=1,nelec !insert the new position into the list at the right place
          if(iold_indices(i).eq.ielec) then
            zzposnew(:,i) = temppos
          endif
        enddo
      endif

c   Now, sort zzposnew.  Hopefully, this will go very quickly for 1-electron moves, since zzposnew 
c      will almost be sorted to begin with.
      
      inew_indices = iold_indices ! initally, zznewpos has same sorting as zzoldpos
      lognb2 = int(dlog(dfloat(nelec))/dlog(2.D0)+1.D-14)
      M = nelec
      do NN=1,lognb2
        M = M/2
        K = nelec - M
        do J = 1,K
          do I =J,1,-M
            L = I + M
            if(zzposnew(1,L).gt.zzposnew(1,I)) exit
            temppos = zzposnew(:,I)
            itemp = inew_indices(I)
            zzposnew(:,I) = zzposnew(:,L)
            inew_indices(I) = inew_indices(L)
            zzposnew(:,L) = temppos
            inew_indices(L) = itemp
          enddo
        enddo
      enddo

c  Now all of the electrons are sorted, and we can calculate observables
      
      zzsumold = 0.d0
      zzsumnew = 0.d0
      stagsignold = 1.0d0/dble(nelec)
      stagsignnew = 1.0d0/dble(nelec)
c     Set the sign of the staggered order such that the n/3rd largest r (or y) has sign +1
c       i.e., in the zigzag phase, sum_i (-1)^i y_i should always be positive
c       Choosing the n/3rd (and not the largest) should hopefully cause zigzag amp = 0 in linear phase

      zztemp2(:) = zzposold(2,:)
      do ipos = 2,nelec/3
        izagold = maxloc(zztemp2,1)
        zztemp2(izagold) = -1.0
      enddo
      izagold = maxloc(zztemp2,1)
      zztemp2(:) = zzposnew(2,:)
      do ipos = 2,nelec/3
        izagnew = maxloc(zztemp2,1)
        zztemp2(izagnew) = -1.0
      enddo
      izagnew = maxloc(zztemp2,1)
      if(mod(izagold,2).eq.0) stagsignold = -stagsignold
      if(mod(izagnew,2).eq.0) stagsignnew = -stagsignnew
c      rave = (q*sum(zzposold(2,:)) + p*sum(zzposnew(2,:)))/dble(nelec)

      do i =1,nelec
        if (iperiodic.eq.0) then
          zzmaglocal_old(i) = stagsignold*(zzposold(2,i)-rring)
          zzmaglocal_new(i) = stagsignnew*(zzposnew(2,i)-rring)
c          zzmaglocal_old(i) = stagsignold*(zzposold(2,i)-rave)
c          zzmaglocal_new(i) = stagsignnew*(zzposnew(2,i)-rave)
        else
          zzmaglocal_old(i) = stagsignold*zzposold(2,i)
          zzmaglocal_new(i) = stagsignnew*zzposnew(2,i)
        endif
        zzsumold = zzsumold + zzmaglocal_old(i)
        zzsumnew = zzsumnew + zzmaglocal_new(i)
        stagsignold = -stagsignold
        stagsignnew = -stagsignnew
      enddo
c  For debugging:
c      write(6,*) 'in zigzag2d:'
c      write(6,*) (zzposold(1,i),i=1,nelec)
c      write(6,*) (zzposold(2,i),i=1,nelec)
c      write(6,*) (zzposnew(1,i),i=1,nelec)
c      write(6,*) (zzposnew(2,i),i=1,nelec)
c      write(6,*) zzsumold, zzsumnew, q*dabs(zzsumold)+p*dabs(zzsumnew)
c      write(6,*) zzsumold, zzsumnew, q*dabs(zzsumold)+p*dabs(zzsumnew)
      zzterm(3) = q*zzsumold + p*zzsumnew
      zzterm(1) = q*dabs(zzsumold) + p*dabs(zzsumnew)
      zzterm(2) = q*zzsumold*zzsumold + p*zzsumnew*zzsumnew
      zzterm(10) = q*(zzsumold**4) + p*(zzsumnew**4)
c     Calculate the values if we throw out max value of y or r and its neighbor
      imaxold = maxloc(zzposold(2,:),1)
      imaxnew = maxloc(zzposnew(2,:),1)
      iminold = minloc(zzposold(2,:),1)
      iminnew = minloc(zzposnew(2,:),1)
c     if (imaxold.eq.nelec) then
c       imaxoldn = 1
c     else
c       imaxoldn = imaxold+1
c     endif
c     if (imaxnew.eq.nelec) then
c       imaxnewn = 1
c     else
c       imaxnewn = imaxnew+1
c     endif
c      zzsumoldred = zzsumold-zzmaglocal_old(imaxold)-zzmaglocal_old(imaxoldn) 
c      zzsumnewred = zzsumnew-zzmaglocal_new(imaxnew)-zzmaglocal_new(imaxnewn) 
      zzsumoldred = zzsumold-zzmaglocal_old(imaxold)-zzmaglocal_old(iminold) 
      zzsumnewred = zzsumnew-zzmaglocal_new(imaxnew)-zzmaglocal_new(iminnew) 
      zzsumoldred = zzsumoldred*dble(nelec)/dble(nelec-2)
      zzsumnewred = zzsumnewred*dble(nelec)/dble(nelec-2)
      zzterm(6) = q*zzsumoldred + p*zzsumnewred
      zzterm(4) = q*dabs(zzsumoldred) + p*dabs(zzsumnewred)
      zzterm(5) = q*zzsumoldred*zzsumoldred + p*zzsumnewred*zzsumnewred
      zzterm(11) = q*(zzsumoldred**4) + p*(zzsumnewred**4)

c     Pick sign randomly, so that N/2 have "-" sign
      ransign(:) = 1.0d0/dble(nelec)
      do itry = 1,nelec/2
        do 
          irand = int(nelec*rannyu(0)) + 1
          if (ransign(irand).gt.0) then
            ransign(irand) = -ransign(irand)
            exit
          endif
        enddo
      enddo
      zzrandsumold = sum(zzposold(2,:)*ransign(:))
      zzrandsumnew = sum(zzposnew(2,:)*ransign(:))
      zzterm(9) = q*zzrandsumold + p*zzrandsumnew
      zzterm(7) = q*dabs(zzrandsumold) + p*dabs(zzrandsumnew)
      zzterm(8) = q*zzrandsumold*zzrandsumold + p*zzrandsumnew*zzrandsumnew
      zzterm(12) = q*(zzrandsumold**4) + p*(zzrandsumnew**4)
      
c     This is a kludge to make sure that the averages come out correctly 
c        for single-electron moves.  Since this routine gets called
c        once per electron in the mov1 update, we need to divide by
c        nelec. This is not needed for all-electron updates, though
c        since we just call this routine once after the update.
      corrnorm = dble(nelec) !makes sure corr is counted properly
      pairdennorm = 1.0d0
      if(ielec.gt.0) then
        zzterm(:) = zzterm(:)/dble(nelec)
        corrnorm = 1.0 ! remember that zzmaglocal^2 has a factor of 1/nelec^2 in it!!
        pairdennorm = 1.0d0/dble(nelec)
      endif
      zzsum(:) = zzsum(:) + zzterm(:)
c     'spread(v,dim,ncopies)' copies an array v, ncopies times along dim
c     zzcorrmat_old = spread(zzmaglocal_old,dim=2,ncopies=nelec)*spread(zzmaglocal_old,dim=1,ncopies=nelec)
c     zzcorrmat_new = spread(zzmaglocal_new,dim=2,ncopies=nelec)*spread(zzmaglocal_new,dim=1,ncopies=nelec)
      
      if(iperiodic.eq.0) then
        delxti = delti
      else
        delxti = delxi(1)
      endif
      delyri = 1.0/zzdelyr

      do j = 0,nelec-1
        do i = 1,nelec
c          i2 = mod(i+j-1,nelec) + 1  !mod returns a number in [0,n-1], array index is [1,n]
          i2 = i + j
          if (i2.gt.nelec) i2 = i2 - nelec
          ! compute difference in x or theta
          xtdiffo = zzposold(1,i2) - zzposold(1,i)
          xtdiffn = zzposnew(1,i2) - zzposnew(1,i)
          if(iperiodic.eq.1) then
            xtdiffo = modulo(xtdiffo,alattice)
            xtdiffn = modulo(xtdiffn,alattice)
            if (xtdiffo.ge.(alattice/2.d0)) xtdiffo = alattice - xtdiffo
            if (xtdiffn.ge.(alattice/2.d0)) xtdiffn = alattice - xtdiffn
          elseif(iperiodic.eq.0) then
            xtdiffo = modulo(xtdiffo,2.d0*3.1415926d0)
            xtdiffn = modulo(xtdiffn,2.d0*3.1415926d0)
            if (xtdiffo.ge.3.1415926d0) xtdiffo = 2.d0*3.1415926d0 - xtdiffo
            if (xtdiffn.ge.3.1415926d0) xtdiffn = 2.d0*3.1415926d0 - xtdiffn
          endif
          ixto = nint(delxti*xtdiffo)
          ixtn = nint(delxti*xtdiffn)
c         zzcorrtermo = q*corrnorm*zzcorrmat_old(i,i2)
c         zzcorrtermn = p*corrnorm*zzcorrmat_new(i,i2)
          zzcorrtermo = q*corrnorm*zzmaglocal_old(i)*zzmaglocal_old(i2)
          zzcorrtermn = p*corrnorm*zzmaglocal_new(i)*zzmaglocal_new(i2)
          zzcorr(ixto) = zzcorr(ixto) + zzcorrtermo
          zzcorr(ixtn) = zzcorr(ixtn) + zzcorrtermn
          zzcorrij(j) = zzcorrij(j) + zzcorrtermo + zzcorrtermn
          if(izigzag.gt.1 .and. j.ne.0) then ! do all of the pair density stuff
            yrdiffo = zzposold(2,i2) - zzposold(2,i)
            yrdiffn = zzposnew(2,i2) - zzposnew(2,i)
            iyro = min(max(nint(delyri*yrdiffo),-NAX),NAX)
            iyrn = min(max(nint(delyri*yrdiffn),-NAX),NAX)
            zzpairden_t(iyro,ixto) = zzpairden_t(iyro,ixto) + q*pairdennorm*0.5
            zzpairden_t(iyro,-ixto) = zzpairden_t(iyro,-ixto) + q*pairdennorm*0.5
            zzpairdenij_t(iyro,j) = zzpairdenij_t(iyro,j) + q*pairdennorm
            zzpairden_t(iyrn,ixtn) = zzpairden_t(iyrn,ixtn) + p*pairdennorm*0.5
            zzpairden_t(iyrn,-ixtn) = zzpairden_t(iyrn,-ixtn) + p*pairdennorm*0.5
            zzpairdenij_t(iyrn,j) = zzpairdenij_t(iyrn,j) + p*pairdennorm
          endif
        enddo
      enddo
      
      xold_sav = xold
      xnew_sav = xnew

    
      return
      end

c-------------------------------------------------------------------

      subroutine print_zigzag_vars(zzave,zzerr,rtpass)

c     Written by Abhijit Mehta, May 2012
c      Routine to print out all the zigzag variables in the
c       various finwrt routines.
c      Inputs: 
c       zzave - array of size nzzvars with averages of all zigzag vars
c       zzerr - array of size nzzvars with errors in all of the averages
c       rtpass - sqrt of the number of passes
c
c        We put all the print out statements here since this code was
c         basically repeated several times throughout CHAMP
c        Now, if we add a new variable, we only need to change the above
c        subroutine (zigzag2d), this subroutine, and the parameter
c        'nzzvars' in zigzag_mod.f90
      
      use zigzag_mod, only: nzzvars

      implicit real*8(a-h,o-z)
      dimension zzave(nzzvars), zzerr(nzzvars)

c  This line is in the finwrt routines:      
c     write(6,'(''physical variable'',t20,''average'',t34,''rms error''
c    &,t47,''rms er*rt(pass)'',t65,''sigma'',t86,''Tcor'')')  !JT

      write(6,'(''<ZigZag Amp> ='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(3),zzerr(3),zzerr(3)*rtpass
      write(6,'(''<|ZigZag Amp|> ='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(1),zzerr(1),zzerr(1)*rtpass
      write(6,'(''<ZigZag Amp^2> ='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(2),zzerr(2),zzerr(2)*rtpass
      write(6,'(''<ZigZag Amp (red)>='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(6),zzerr(6),zzerr(6)*rtpass
      write(6,'(''<|ZigZag Amp| (red)>='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(4),zzerr(4),zzerr(4)*rtpass
      write(6,'(''<ZigZag Amp^2 (red)>='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(5),zzerr(5),zzerr(5)*rtpass
      write(6,'(''<ZigZag rand Amp>='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(9),zzerr(9),zzerr(9)*rtpass
      write(6,'(''<|ZigZag rand Amp|>='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(7),zzerr(7),zzerr(7)*rtpass
      write(6,'(''<ZigZag rand Amp^2>='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(8),zzerr(8),zzerr(8)*rtpass
      write(6,'(''<ZigZag Amp^4> ='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(10),zzerr(10),zzerr(10)*rtpass
      write(6,'(''<ZigZag Amp^4 (red)>='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(11),zzerr(11),zzerr(11)*rtpass
      write(6,'(''<ZigZag rand Amp^4>='',t22,f12.7,'' +-'',f11.7,f9.5)') zzave(12),zzerr(12),zzerr(12)*rtpass
      
      return
      end
