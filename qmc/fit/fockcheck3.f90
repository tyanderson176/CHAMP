      subroutine fockcheck3(o,op,diff,isht,nfsh,it,ipr)
! Written by Cyrus Umrigar and Claudia Filippi
      use constants_mod
      use atom_mod
      use contr2_mod
      use jaspar3_mod
      use pars_mod
      use ncusp_mod
      use confg_mod
      implicit real*8(a-h,o-z)

      parameter(d1b24=1.d0/24.d0,d1b4=0.25d0,d1b6=1.d0/6.d0,d1b12=1.d0/12.d0 &
     &,rt2=1.414213562373095d0,dln2=0.6931471805599453d0 &
     &,const1=(1.d0-dln2)/12.d0)
!    &,const1=(1.d0-dln2)/12.d0,const2=-(pi-2.d0)/(6.d0*pi))

      dimension o(2*nord),op(0:2*nord),diff(*)

! f2e o(s^2) from phi20(r12=0)
! f2n o(r^2) from phi20(r1=0)
! f2elog o(s^2 log(s)) from phi21(r12=0)

      if(ifock.eq.4) then
        zfock=znuc(iwctype(it))
        f2n=-d1b6*(eguess+zfock*(zfock-dln2))-d1b24
        f2e=-d1b12*eguess + (const1-d1b4*zfock)*zfock

        o(2)=o(2)+fck(2,it,1)*f2n
        o(2+nord)=o(2+nord)+fck(2,it,1)*f2e+half*a21
       else
        o(2) =o(2)+fck(4,it,1)+fck(5,it,1)+fck(6,it,1) &
     &            +fck(7,it,1)+fck(8,it,1)+fck(9,it,1)
        op(1)=op(1)+fck(5,it,1)+three*fck(7,it,1)+fck(8,it,1)+two*fck(9,it,1)
        o(2+nord) =o(2+nord) +rt2*(half*fck(5,it,1)+fck(7,it,1))
        op(1+nord)=op(1+nord)+rt2*(half*fck(4,it,1)+fck(9,it,1))
      endif

      if(ifock.ne.2) return

      nfsh=nfock/2
      ishn=nord
      ishe=2*nord+nfsh

      alp2n=2*(3*fck(11,it,1)+fck(12,it,1)+2*fck(13,it,1) &
     &        -2*fck(14,it,1)-fck(15,it,1))
      alp2e=two*fck(13,it,1)

      diff(isht+ishn+1) = alp2n
      diff(isht+ishe+1) = alp2e

      if(ipr.ge.1) then
        write(6,'(''coefs of r2lg'',f12.6)') diff(isht+ishn+1)
        write(6,'(''coefs of s2lg'',f12.6)') diff(isht+ishe+1)
      endif

      return
      end
