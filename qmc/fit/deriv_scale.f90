      subroutine deriv_scale(r,dk,dk2,dr,dr2,iflag,id)
! Written by A.D.Guclu, jun2005, following the subroutine scale_dist2
! Calculates quantities related to derivatives of scaling function R:
! dk = dR/dk
! dr = d/dr(dk)
! dr2= d2/dr2(dk)
! called by deriv_jastrow4. Assuming ijas is 4.
! iflag = 1  e-n terms in f_{en}
!         2  e-e terms in f_{ee}
!         3  e-n terms in f_{een}
!         4  e-e terms in f_{een}
! id != 0   calculate only dk
!     = 1   calculate dk,dr,dr2
!     = 2   calculate dk2,dk,dr,dr2
! input: r,iflag
! output: dk,dk2,dr,dr2

      use contr2_mod
      use wfsec_mod
      use jaspar3_mod
      use jaspar6_mod
      implicit real*8(a-h,o-z)


!JT      parameter (zero=0.d0,one=1.d0,two=2.d0,half=0.5d0,third=1.d0/3.d0,d4b3=4.d0/3.d0)
      parameter (d4b3=4.d0/3.d0)


      if(iflag.eq.1.or.iflag.eq.3) then
        cutjas=cutjas_en
        cutjasi=cutjasi_en
!        asymp_r=asymp_r_en(iwf)
       elseif(iflag.eq.2.or.iflag.eq.4) then
        cutjas=cutjas_ee
        cutjasi=cutjasi_ee
!        asymp_r=asymp_r_ee(iwf)
      endif

      if(isc.eq.2 .or. (isc.eq.12.and.(iflag.eq.1.or.iflag.eq.2))) then
        call deriv_isc2(r,dk,dk2,dr,dr2,scalek(iwf),id)

! isc=3 not used
!      elseif(isc.eq.3) then
!        call deriv_isc3(r,dk,dk2,dr,dr2,scalek(iwf),id)

      elseif(isc.eq.4 .or. (isc.eq.14.and.(iflag.eq.1.or.iflag.eq.2))) then
        call deriv_isc4(r,dk,dk2,dr,dr2,scalek(iwf),id)

! isc=5 not used
!      elseif(isc.eq.5) then
!        call deriv_isc5(r,dk,dk2,dr,dr2,scalek(iwf),id)

      elseif(isc.eq.6 .or. (isc.eq.16.and.(iflag.eq.1.or.iflag.eq.2))) then
        call deriv_isc6(r,dk,dk2,dr,dr2,scalek(iwf),cutjas,cutjasi,id)

      elseif(isc.eq.7 .or. (isc.eq.17.and.(iflag.eq.1.or.iflag.eq.2))) then
        call deriv_isc7(r,dk,dk2,dr,dr2,scalek(iwf),cutjas,cutjasi,id)

      elseif(isc.eq.8) then
        call deriv_isc2(r,dk,dk2,dr,dr2,scalek(iwf),id)

      elseif(isc.eq.10) then
        call deriv_isc4(r,dk,dk2,dr,dr2,scalek(iwf),id)

      elseif(isc.eq.16 .and. iflag.ge.3) then
        call deriv_isc16(r,dk,dk2,dr,dr2,scalek(iwf),cutjas,cutjasi,id)

      elseif(isc.eq.12 .and. iflag.ge.3) then
        call deriv_isc12(r,dk,dk2,dr,dr2,scalek(iwf),id)

      elseif(isc.eq.17 .and. iflag.ge.3) then
        call deriv_isc17(r,dk,dk2,dr,dr2,scalek(iwf),cutjas,cutjasi,id)

      elseif(isc.eq.14 .and. iflag.ge.3) then
        call deriv_isc14(r,dk,dk2,dr,dr2,scalek(iwf),id)

      else
        stop 'isc value not allowed in deriv_scale.f'
      endif

      return
      end

!------------------------------------------------------------------------------

      subroutine deriv_isc2(r,dk,dk2,dr,dr2,sk,id)

      implicit real*8(a-h,o-z)

      rk=sk*r
      exprk=dexp(-rk)
      sk2=sk*sk

      dk=((rk+1)*exprk-1.d0)/sk2
      if(id.ge.1) then
        dr=-r*exprk
        dr2=(rk-1.d0)*exprk
        if(id.eq.2) then
          dk2=-rk*rk*exprk/(sk2*sk)-2/sk*dk
        endif
      endif

      return
      end

!------------------------------------------------------------------------------

      subroutine deriv_isc4(r,dk,dk2,dr,dr2,sk,id)

      implicit real*8(a-h,o-z)

      rk=sk*r
      term=1+rk
      term2=term*term

      dk=-r*r/term2
      if(id.ge.1) then
        term3=term2*term
        term4=term3*term
        dr=-2*r/term3
        dr2=(4*rk-2)/term4
        if(id.eq.2) then
          dk2=-2*r/term*dk
        endif
      endif

      return
      end

!------------------------------------------------------------------------------

      subroutine deriv_isc6(r,dk,dk2,dr,dr2,sk,cutjas,cutjasi,id)

      implicit real*8(a-h,o-z)
      parameter (third=1.d0/3.d0)

      if(r.lt.cutjas) then

        rbyrc=r*cutjasi
        rbyrc2=rbyrc*rbyrc
        f=r*(1-rbyrc+third*rbyrc2)
        fk=sk*f
        expfk=dexp(-fk)
        sk2=sk*sk

        dk=((fk+1)*expfk-1)/sk2
        if(id.ge.1) then
          fp=1-2*rbyrc+rbyrc2
          fpp=2*cutjasi*(rbyrc-1)
          dr=-f*fp*expfk
          dr2=((fk-1)*fp*fp-f*fpp)*expfk
          if(id.eq.2) then
            dk2=-fk*fk*expfk/(sk2*sk)-2/sk*dk
          endif
        endif

! perhaps following is redundant?
      else

        rckby3=sk*cutjas*third
        exp=dexp(-rckby3)

        dk=((rckby3+1)*exp-1)/(sk*sk)
        if(id.eq.2) then
          dk2=-rckby3*rckby3*exp/(sk*sk*sk)-2/sk*dk
        endif
        dr=0
        dr2=0

      endif

      return
      end

!------------------------------------------------------------------------------

      subroutine deriv_isc7(r,dk,dk2,dr,dr2,sk,cutjas,cutjasi,id)

      implicit real*8(a-h,o-z)
      parameter (third=1.d0/3.d0)

      if(r.lt.cutjas) then

        rbyrc=r*cutjasi
        rbyrc2=rbyrc*rbyrc
        f=r*(1-rbyrc+third*rbyrc2)
        fk=sk*f
        term=fk+1
        term2=term*term

        dk=-f*f/term2
        if(id.ge.1) then
          fp=1-2*rbyrc+rbyrc2
          fpp=2*cutjasi*(rbyrc-1)
          term3=term2*term
          term4=term3*term
          dr=-2*f*fp/term3
          dr2=2*((2*fk-1)*fp*fp-f*fpp*term)/term4
          if(id.eq.2) then
            dk2=-2*f/term*dk
          endif
        endif

      else

        f=third*cutjas
        term=1+sk*f

        dk=-f*f/(term*term)
        dr=0
        dr2=0
        if(id.eq.2) then
          dk2=-2*f/term*dk
        endif

      endif

      return
      end

!------------------------------------------------------------------------------

      subroutine deriv_isc8(r,dk,dk2,dr,dr2,sk,id)

      implicit real*8(a-h,o-z)

      rk=sk*r
      exprk=dexp(-rk)
      sk2=sk*sk

      stop 'deriv_isc8 not yet available'

      dk=((rk+1)*exprk-1.d0)/sk2
      if(id.ge.1) then
        dr=-r*exprk
        dr2=(rk-1.d0)*exprk
        if(id.eq.2) then
          dk2=-rk*rk*exprk/(sk2*sk)-2/sk*dk
        endif
      endif

      return
      end

!------------------------------------------------------------------------------

      subroutine deriv_isc10(r,dk,dk2,dr,dr2,sk,id)

      implicit real*8(a-h,o-z)

      stop 'deriv_isc10 not yet available'

      rk=sk*r
      term=1+rk
      term2=term*term

      dk=-r*r/term2
      if(id.ge.1) then
        term3=term2*term
        term4=term3*term
        dr=-2*r/term3
        dr2=(4*rk-2)/term4
        if(id.eq.2) then
          dk2=-2*r/term*dk
        endif
      endif

      return
      end


!------------------------------------------------------------------------------

      subroutine deriv_isc12(r,dk,dk2,dr,dr2,sk,id)
! this function can be optimized little more

      implicit real*8(a-h,o-z)

      f=r*r
      fk=sk*f
      expfk=dexp(-fk)
      sk2=sk*sk

      dk=((fk+1)*expfk-1)/sk2
      if(id.ge.1) then
        fp=2*r
        fpp=2
        dr=-f*fp*expfk
        dr2=((fk-1)*fp*fp-f*fpp)*expfk
        if(id.eq.2) then
          dk2=-fk*fk*expfk/(sk2*sk)-2/sk*dk
        endif
      endif

      return
      end

!------------------------------------------------------------------------------

      subroutine deriv_isc14(r,dk,dk2,dr,dr2,sk,id)
! this function can be optimized little more

      implicit real*8(a-h,o-z)

      f=r*r
      fk=sk*f
      term=fk+1
      term2=term*term

      dk=-f*f/term2
      if(id.ge.1) then
        fp=2*r
        fpp=2
        term3=term2*term
        term4=term3*term
        dr=-2*f*fp/term3
        dr2=2*((2*fk-1)*fp*fp-f*fpp*term)/term4
        if(id.eq.2) then
          dk2=-2*f/term*dk
        endif
      endif

      return
      end

!------------------------------------------------------------------------------

      subroutine deriv_isc16(r,dk,dk2,dr,dr2,sk,cutjas,cutjasi,id)

      implicit real*8(a-h,o-z)
      parameter (half=0.5d0,d4b3=4.d0/3.d0,third=1.d0/3.d0)

      if(r.lt.cutjas) then

        rbyrc=r*cutjasi
        rbyrc2=rbyrc*rbyrc
        f=r*r*(1-d4b3*rbyrc+half*rbyrc2)
        fk=sk*f
        expfk=dexp(-fk)
        sk2=sk*sk

        dk=((fk+1)*expfk-1)/sk2
        if(id.ge.1) then
          fp=2*r*(1-2*rbyrc+rbyrc2)
          fpp=2*(1-4*rbyrc+3*rbyrc2)
          dr=-f*fp*expfk
          dr2=((fk-1)*fp*fp-f*fpp)*expfk
          if(id.eq.2) then
            dk2=-fk*fk*expfk/(sk2*sk)-2/sk*dk
          endif
        endif

      else

! using isc=6 asymptotic value:
        rckby3=sk*cutjas*third
        exp=dexp(-rckby3)

        dk=((rckby3+1)*exp-1)/(sk*sk)
        if(id.eq.2) then
          dk2=-rckby3*rckby3*exp/(sk*sk*sk)-2/sk*dk
        endif
        dr=0
        dr2=0

      endif

      return
      end

!------------------------------------------------------------------------------
      subroutine deriv_isc17(r,dk,dk2,dr,dr2,sk,cutjas,cutjasi,id)

      implicit real*8(a-h,o-z)
      parameter (half=0.5d0,d4b3=4.d0/3.d0,third=1.d0/3.d0)

      if(r.lt.cutjas) then

        rbyrc=r*cutjasi
        rbyrc2=rbyrc*rbyrc
        f=r*r*(1-d4b3*rbyrc+half*rbyrc2)
        fk=sk*f
        term=fk+1
        term2=term*term

        dk=-f*f/term2
        if(id.ge.1) then
          fp=2*r*(1-2*rbyrc+rbyrc2)
          fpp=2*(1-4*rbyrc+3*rbyrc2)
          term3=term2*term
          term4=term3*term
          dr=-2*f*fp/term3
          dr2=2*((2*fk-1)*fp*fp-f*fpp*term)/term4
          if(id.eq.2) then
            dk2=-2*f/term*dk
          endif
        endif

      else

        f=third*cutjas
        term=1+sk*f

        dk=-f*f/(term*term)
        dr=0
        dr2=0
        if(id.eq.2) then
          dk2=-2*f/term*dk
        endif

      endif

      return
      end

!------------------------------------------------------------------------------

      subroutine switch_dscale(rr,dd1,dd2,dk,dk2,dr,dr2,iflag,id)
! by A.D.Guclu, 2005jul
! Switch scaling for ijas=4,5 from that appropriate for A,B terms to
! that appropriate for C terms, for d/dk(R) and 1st two derivs.

      use wfsec_mod
      use jaspar3_mod
      use jaspar6_mod
      implicit real*8(a-h,o-z)



      if(iflag.eq.1.or.iflag.eq.3) then
        asympi=1/asymp_r_en(iwf)
        dasymp=dasymp_r_en(iwf)
        d2asymp=d2asymp_r_en(iwf)
       elseif(iflag.eq.2.or.iflag.eq.4) then
        asympi=1/asymp_r_ee(iwf)
        dasymp=dasymp_r_ee(iwf)
        d2asymp=d2asymp_r_ee(iwf)
      endif

      dk=((1-rr)*dasymp-dk)*asympi
      if(id.ge.1) then
        dr=-(dd1*dasymp+dr)*asympi
        dr2=-(dd2*dasymp+dr2)*asympi
        if(id.eq.2) then
          dk2=(-2*dk*dasymp+(1-rr)*d2asymp-dk2)*asympi
!          dk2=(-dk*dasymp+(1-rr)*d2asymp-dk2-dk)*asympi
        endif
      endif

      return
      end
!-----------------------------------------------------------------------
