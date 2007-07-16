!-----------------------------------------------------------------------
      subroutine sites_dmc
!-----------------------------------------------------------------------
!     Description: random configurations for DMC on the model of the
!     routine 'sites' used in VMC
!     Created: J. Toulouse, 18 Mar 2007
!-----------------------------------------------------------------------
      implicit real*8(a-h,o-z)

      include '../vmc/vmc.h'
      include '../vmc/force.h'
      include 'dmc.h'

      dimension nsite(MCENT)
      common /const/ pi,hb,etrial,delta,deltai,fbias,nelec,imetro,ipr
      common /contrl/ nstep,nblk,nblkeq,nconf,nconf_new,isite,idump,irstar
      common /config_dmc/ xoldw(3,MELEC,MWALK,MFORCE),voldw(3,MELEC,MWALK,MFORCE),
     &psidow(MWALK,MFORCE),psijow(MWALK,MFORCE),peow(MWALK,MFORCE),peiow(MWALK,MFORCE),d2ow(MWALK,MFORCE)
      common /dim/ ndim
      common /atom/ znuc(MCTYPE),cent(3,MCENT),pecent
     &,iwctype(MCENT),nctype,ncent


!     sites
      l=0
      do i=1,ncent
        nsite(i)=int(znuc(iwctype(i))+0.5d0)
        l=l+nsite(i)
        if(l.gt.nelec) then
          nsite(i)=nsite(i)-(l-nelec)
          l=nelec
        endif
      enddo
      if(l.lt.nelec) nsite(1)=nsite(1)+(nelec-l)

c loop over spins and centers. If odd number of electrons on all
c atoms then the up-spins have an additional electron.

      l=0
      do 10 ispin=1,2
        do 10 i=1,ncent
          ju=(nsite(i)+2-ispin)/2
          if(znuc(iwctype(i)).eq.0.d0) stop 'znuc should not be 0 in sites' 
          do 10 j=1,ju
            l=l+1
            if(l.gt.nelec) return
            if(j.eq.1) then
              sitsca=1/znuc(iwctype(i))
             elseif(j.le.5) then
              sitsca=2/(znuc(iwctype(i))-2)
             else
              sitsca=3/(znuc(iwctype(i))-10)
            endif

!           sample position from exponentials around center
            do 10 iconf=1,nconf
             do 10 k=1,ndim
             site=-dlog(rannyu(0))
             site=sign(site,(rannyu(0)-0.5d0))
   10        xoldw(k,l,iconf,1)=sitsca*site+cent(k,i)
       
      write(6,'(i4,a,i3,a)') nconf,' configurations for',l,' electrons have been randomly generated.'
      write(6,'()')

       
      open(9,file='mc_configs_sites',status='unknown')
!write(fmt,'(a1,i2,a21)')'(',ndim*nelec,'f14.8,i3,d12.4,f12.5)'

      do iconf=1,nconf
       write(9,'(1000f12.8)')  ((xoldw(k,j,iconf,1),k=1,ndim),j=1,nelec)
      enddo
      close(9)

      if(l.lt.nelec) stop 'bad input to sites'
      return
      end
