      subroutine sites_per(xoldw,nelec,nup,ndn,rlatt_sim)
c Written by Cyrus Umrigar
c routine to put electrons down electrons in approximately a uniform
c mesh if nothing else is available.  Do not make random part eps too
c small otherwise in parallel mode configurations on different processors
c will be close to each other.

      implicit real*8(a-h,o-z)
      include '../vmc/vmc.h'

      parameter(half=0.5d0,eps=1.d-1)

      character*26 fmt

      common /dim/ ndim

      dimension xoldw(3,*),rlatt_sim(3,3),ilat(3),frac(3)

c     write(6,'(''rlatt_sim'',3(3f9.4))') rlatt_sim
c do up-spin electrons
      nlin=(dfloat(nup))**(1.d0/3.d0)+1
      if((nlin-1)**3.ge.nup) then
        nlin1=nlin-1
        nlin2=nlin-1
        nlin3=nlin-1
       elseif(nlin*(nlin-1)**2.ge.nup) then
        nlin1=nlin
        nlin2=nlin-1
        nlin3=nlin-1
       elseif(nlin**2*(nlin-1).ge.nup) then
        nlin1=nlin
        nlin2=nlin
        nlin3=nlin-1
       else
        nlin1=nlin
        nlin2=nlin
        nlin3=nlin
      endif
c     write(6,'(''nlin1,nlin2,nlin3=''3i4)') nlin1,nlin2,nlin3

      frac(1)=1.d0/(nlin1)
      frac(2)=1.d0/(nlin2)
      frac(3)=1.d0/(nlin3)

      ielec=0
      do 10 i1=1,nlin1
        ilat(1)=i1
        do 10 i2=1,nlin2
          ilat(2)=i2
          do 10 i3=1,nlin3
            ilat(3)=i3
            ielec=ielec+1
            if(ielec.gt.nup) goto 20
            do 10 k=1,ndim
              xoldw(k,ielec)=0
              do 10 i=1,ndim
   10           xoldw(k,ielec)=xoldw(k,ielec)+rlatt_sim(k,i)*frac(i)*(ilat(i)-1)+eps*rannyu(0)


c do dn-spin electrons
   20 nlin=(dfloat(ndn))**(1.d0/3.d0)+1
      if((nlin-1)**3.ge.ndn) then
        nlin1=nlin-1
        nlin2=nlin-1
        nlin3=nlin-1
       elseif(nlin*(nlin-1)**2.ge.ndn) then
        nlin1=nlin
        nlin2=nlin-1
        nlin3=nlin-1
       elseif(nlin**2*(nlin-1).ge.ndn) then
        nlin1=nlin
        nlin2=nlin
        nlin3=nlin-1
       else
        nlin1=nlin
        nlin2=nlin
        nlin3=nlin
      endif
c     write(6,'(''nlin1,nlin2,nlin3=''3i4)') nlin1,nlin2,nlin3

      frac(1)=1.d0/(nlin1)
      frac(2)=1.d0/(nlin2)
      frac(3)=1.d0/(nlin3)

      ielec=nup
      do 30 i1=1,nlin1
        ilat(1)=i1
        do 30 i2=1,nlin2
          ilat(2)=i2
          do 30 i3=1,nlin3
            ilat(3)=i3
            ielec=ielec+1
            if(ielec.gt.nelec) goto 40
            do 30 k=1,ndim
              xoldw(k,ielec)=0
              do 30 i=1,ndim
   30           xoldw(k,ielec)=xoldw(k,ielec)+rlatt_sim(k,i)*frac(i)*(ilat(i)-half)+eps*rannyu(0)

c Temporary debug write
   40 if(ndim*nelec.lt.10) then
        write(fmt,'(a1,i1,a21)')'(',ndim*nelec,'f13.8,i3,d12.4,f12.5)'
       elseif(ndim*nelec.lt.100) then
        write(fmt,'(a1,i2,a21)')'(',ndim*nelec,'f13.8,i3,d12.4,f12.5)'
       elseif(ndim*nelec.lt.1000) then
        write(fmt,'(a1,i3,a21)')'(',ndim*nelec,'f13.8,i3,d12.4,f12.5)'
       elseif(ndim*nelec.lt.10000) then
        write(fmt,'(a1,i4,a21)')'(',ndim*nelec,'f13.8,i3,d12.4,f12.5)'
      endif
      write(7,fmt) ((xoldw(k,ielec),k=1,ndim),ielec=1,nelec)

c Check that there are no close ones.
      do 60 i=2,nelec
        do 60 j=1,i-1
          dist=0
          do 50 k=1,ndim
   50       dist=dist+(xoldw(k,i)-xoldw(k,j))**2
          dist=sqrt(dist)
          if(dist.lt.1.d-3) then
            write(6,'(9d12.4)') (xoldw(k,i),xoldw(k,j),k=1,ndim)
            write(6,'(''electrons'',i4,'' and'',i4,'' are too close'',d12.4)') i,j,dist
            stop  'electrons in sites_per are too close'
          endif
   60 continue

      return
      end
