      subroutine fourierrk(p,q,xold,xnew)

! Written by A.D.Guclu aug2006.
! Calculates the power spectrum estimator in polar coo., defined as:
!     FT=abs( sum_i Fourier[Delta^2(r_i-r)])^2
! taking the absolute value before the data accumulation is essential to get the
! "internal structure" of the density.

! Notes:
! Delta^2(ri-r)=Delta(ri_r) Delta(thetai-theta) / r
! We consider only angular FT here.
! Fourier[Delta]=cos + i sin

! In practice, there is a uninteresting constant term that we substract:
! FT(renormalized)= r^2 FT - N(r)   where N(r) is number of electrons at r.

! During the print out we divide everything by r^2 to get the final result.
! FT(r,k=0)= electronic density

! Modified by A. C. Mehta, November 2011 to work with periodic wires

!  In this case, we replace "r" by "y" (the transverse coordinate),
!    and we take the FT in the x-direction (rather than theta)
!  There is no 1/r term in cartesian coordinates, so:
!  FT(renormalized) = FT - N(r)
!  and there is no need to divide everything by r^2
!   (we modify printout routines to reflect this)
!   Note we take cos(k_x (x_i - x_j) *2*pi/alattice)
!
!  Also, for the purposes of the periodic wires, we use the variables
!    labeled with "r" to represent quantities having to do with "y"
!    and we use the variables labeled with "theta" to represent
!    quantities having to do with "x" (the periodic direction in wires)


      use dets_mod
      use const_mod
      use dim_mod
      use pairden_mod
      use fourier_mod
      use contrl_per_mod
      use periodic_1d_mod
      implicit real*8(a-h,o-z)

      dimension xold(3,nelec),xnew(3,nelec)
      dimension fcos_uo(-NAX:NAX),fcos_do(-NAX:NAX)
      dimension fsin_uo(-NAX:NAX),fsin_do(-NAX:NAX)
      dimension fcos_un(-NAX:NAX),fcos_dn(-NAX:NAX)
      dimension fsin_un(-NAX:NAX),fsin_dn(-NAX:NAX)
      dimension nr_uo(-NAX:NAX),nr_do(-NAX:NAX),nr_un(-NAX:NAX),nr_dn(-NAX:NAX)
      common /circularmesh/ rmin,rmax,rmean,delradi,delti,nmeshr,nmesht,icoosys
      common /dot/ w0,we,bext,emag,emaglz,emagsz,glande,p1,p2,p3,p4,rring

      if(iperiodic.eq.1) then
        naxmin = -NAX
        naxmax = NAX
        thetafactor = 2.d0*pi/alattice
      elseif(rring.eq.0.d0) then
        naxmin = 1
        naxmax = NAX
      else
        naxmin = -nmeshr
        naxmax = nmeshr
      endif

      do ik=0,nmeshk1
        fk=delk1*ik
! reset temporary arrays:
        do ix=-NAX,NAX
          fcos_uo(ix)=0.d0
          fcos_do(ix)=0.d0
          fsin_uo(ix)=0.d0
          fsin_do(ix)=0.d0
          fcos_un(ix)=0.d0
          fcos_dn(ix)=0.d0
          fsin_un(ix)=0.d0
          fsin_dn(ix)=0.d0
          nr_uo(ix)=0
          nr_do(ix)=0
          nr_un(ix)=0
          nr_dn(ix)=0
        enddo

        do ie=1,nelec
          if(iperiodic.eq.1) then
            rold = xold(2,ie)
            rnew = xnew(2,ie)
            thetao = thetafactor*xold(1,ie)
            thetan = thetafactor*xnew(1,ie)
            iro = min(max(nint(delxi(2)*rold),-NAX), NAX)
            irn = min(max(nint(delxi(2)*rnew),-NAX), NAX)
          else
            rold=0.d0
            rnew=0.d0
            do  idim=1,ndim
              rold=rold+xold(idim,ie)**2
              rnew=rnew+xnew(idim,ie)**2
            enddo
            rold=dsqrt(rold)
            rnew=dsqrt(rnew)
            thetao=datan2(xold(2,ie),xold(1,ie))
            thetan=datan2(xnew(2,ie),xnew(1,ie))
            if (rring.eq.0.d0) then
              iro=min(int(delxi(2)*rold)+1,NAX)
              irn=min(int(delxi(2)*rnew)+1,NAX)
            else
              iro = min(max(nint(delradi*(rold-rmean)),-NAX), NAX)
              irn = min(max(nint(delradi*(rnew-rmean)),-NAX), NAX)
            endif
          endif

          if(ie.le.nup) then
            fcos_uo(iro)=fcos_uo(iro)+dcos(fk*thetao)
            fsin_uo(iro)=fsin_uo(iro)+dsin(fk*thetao)
            fcos_un(irn)=fcos_un(irn)+dcos(fk*thetan)
            fsin_un(irn)=fsin_un(irn)+dsin(fk*thetan)
            nr_uo(iro)=nr_uo(iro)+1
            nr_un(irn)=nr_un(irn)+1
          else
            fcos_do(iro)=fcos_do(iro)+dcos(fk*thetao)
            fsin_do(iro)=fsin_do(iro)+dsin(fk*thetao)
            fcos_dn(irn)=fcos_dn(irn)+dcos(fk*thetan)
            fsin_dn(irn)=fsin_dn(irn)+dsin(fk*thetan)
            nr_do(iro)=nr_do(iro)+1
            nr_dn(irn)=nr_dn(irn)+1
          endif

        enddo

        do ir=naxmin,naxmax
          fourierrk_u(ir,ik)=fourierrk_u(ir,ik)+(fcos_uo(ir)*fcos_uo(ir)+fsin_uo(ir)*fsin_uo(ir))*q
          fourierrk_d(ir,ik)=fourierrk_d(ir,ik)+(fcos_do(ir)*fcos_do(ir)+fsin_do(ir)*fsin_do(ir))*q
          fourierrk_t(ir,ik)=fourierrk_t(ir,ik)+((fcos_uo(ir)+fcos_do(ir))**2 &
     &                                               +(fsin_uo(ir)+fsin_do(ir))**2)*q
          fourierrk_u(ir,ik)=fourierrk_u(ir,ik)+(fcos_un(ir)*fcos_un(ir)+fsin_un(ir)*fsin_un(ir))*p
          fourierrk_d(ir,ik)=fourierrk_d(ir,ik)+(fcos_dn(ir)*fcos_dn(ir)+fsin_dn(ir)*fsin_dn(ir))*p
          fourierrk_t(ir,ik)=fourierrk_t(ir,ik)+((fcos_un(ir)+fcos_dn(ir))**2 &
     &                                               +(fsin_un(ir)+fsin_dn(ir))**2)*p
! substract the infinite k limit:
          fourierrk_u(ir,ik)=fourierrk_u(ir,ik)-nr_uo(ir)*q
          fourierrk_d(ir,ik)=fourierrk_d(ir,ik)-nr_do(ir)*q
          fourierrk_t(ir,ik)=fourierrk_t(ir,ik)-(nr_uo(ir)+nr_do(ir))*q

          fourierrk_u(ir,ik)=fourierrk_u(ir,ik)-nr_un(ir)*p
          fourierrk_d(ir,ik)=fourierrk_d(ir,ik)-nr_dn(ir)*p
          fourierrk_t(ir,ik)=fourierrk_t(ir,ik)-(nr_un(ir)+nr_dn(ir))*p

        enddo
!        write(6,*) 'fourierrk_t=',fourierrk_t(ir,ik)
      enddo

      return
      end

!-------------------------------------------------------------------------------------
      subroutine fourierrk_old(p,q,xold,xnew)

! Written by A.D.Guclu aug2006.
! Calculates the "internal fourier transform" estimator in polar coo., defined as:
!     FT=abs( sum_i Fourier[Delta^2(r_i-r)])
! taking the absolute value before the data accumlation is essential to get the
! "internal structure" of the density. We are indeed calculation the following
! quantity:
!     <FT>=<Psi| abs( Fourier[rho(r)] ) |Psi>
! Notes:
! Delta^2(ri-r)=Delta(ri_r) Delta(thetai-theta) / r
! We consider only angular FT here.
! Fourier[Delta]=cos + i sin

! FT(r,k=0)= electronic density


      use dets_mod
      use const_mod
      use dim_mod
      use pairden_mod
      use fourier_mod
      implicit real*8(a-h,o-z)

      dimension xold(3,nelec),xnew(3,nelec)
      dimension fcos_uo(NAX),fcos_do(NAX)
      dimension fsin_uo(NAX),fsin_do(NAX)
      dimension fcos_un(NAX),fcos_dn(NAX)
      dimension fsin_un(NAX),fsin_dn(NAX)

      big=1000.d0

      do ik=0,NAK1
        if(ik.eq.NAK1) then
          fk=big    !last point represents infinity. inconsistent with the new den2dwrt.f
        else
          fk=delk1*ik
        endif
! reset temporary arrays:
        do ix=1,NAX
          fcos_uo(ix)=0.d0
          fcos_do(ix)=0.d0
          fsin_uo(ix)=0.d0
          fsin_do(ix)=0.d0
          fcos_un(ix)=0.d0
          fcos_dn(ix)=0.d0
          fsin_un(ix)=0.d0
          fsin_dn(ix)=0.d0
        enddo

        do ie=1,nelec

          rold=0.d0
          rnew=0.d0
          do  idim=1,ndim
            rold=rold+xold(idim,ie)**2
            rnew=rnew+xnew(idim,ie)**2
          enddo
          rold=dsqrt(rold)
          rnew=dsqrt(rnew)
          thetao=datan2(xold(2,ie),xold(1,ie))
          thetan=datan2(xnew(2,ie),xnew(1,ie))
          iro=min(int(delxi(2)*rold)+1,NAX)
          irn=min(int(delxi(2)*rnew)+1,NAX)

          if(ie.le.nup) then
            fcos_uo(iro)=fcos_uo(iro)+dcos(fk*thetao)
            fsin_uo(iro)=fsin_uo(iro)+dsin(fk*thetao)
            fcos_un(irn)=fcos_un(irn)+dcos(fk*thetan)
            fsin_un(irn)=fsin_un(irn)+dsin(fk*thetan)
          else
            fcos_do(iro)=fcos_do(iro)+dcos(fk*thetao)
            fsin_do(iro)=fsin_do(iro)+dsin(fk*thetao)
            fcos_dn(irn)=fcos_dn(irn)+dcos(fk*thetan)
            fsin_dn(irn)=fsin_dn(irn)+dsin(fk*thetan)
          endif

        enddo

        do ir=1,NAX
          fourierrk_u(ir,ik)=fourierrk_u(ir,ik)+dsqrt(fcos_uo(ir)*fcos_uo(ir)+fsin_uo(ir)*fsin_uo(ir))*q
          fourierrk_d(ir,ik)=fourierrk_d(ir,ik)+dsqrt(fcos_do(ir)*fcos_do(ir)+fsin_do(ir)*fsin_do(ir))*q
          fourierrk_t(ir,ik)=fourierrk_t(ir,ik)+dsqrt((fcos_uo(ir)+fcos_do(ir))**2 &
     &                                               +(fsin_uo(ir)+fsin_do(ir))**2)*q
          fourierrk_u(ir,ik)=fourierrk_u(ir,ik)+dsqrt(fcos_un(ir)*fcos_un(ir)+fsin_un(ir)*fsin_un(ir))*p
          fourierrk_d(ir,ik)=fourierrk_d(ir,ik)+dsqrt(fcos_dn(ir)*fcos_dn(ir)+fsin_dn(ir)*fsin_dn(ir))*p
          fourierrk_t(ir,ik)=fourierrk_t(ir,ik)+dsqrt((fcos_un(ir)+fcos_dn(ir))**2 &
     &                                               +(fsin_un(ir)+fsin_dn(ir))**2)*p
        enddo
!        write(6,*) 'fourierrk_t=',fourierrk_t(ir,ik)
      enddo

      return
      end

!-------------------------------------------------------------------------------------

      subroutine fourierkk(p,q,xold,xnew)

! Written by A.D.Guclu aug2006.
! Calculates the "internal fourier transform" estimator in cartesian coo., defined as:
!     FT=abs( sum_i Fourier[Delta^2(r_i-r)])
! taking the absolute value before the data accumlation is essential to get the
! "internal structure" of the density. We are indeed calculation the following
! quantity:
!     <FT>=<Psi| abs( Fourier[rho(r)] ) |Psi>
! Notes:
! Delta^2(ri-r)=Delta(xi-x) Delta(yi-y)
! Fourier[Delta]=cos + i sin

      use dets_mod
      use const_mod
      use dim_mod
      use fourier_mod
      implicit real*8(a-h,o-z)

      dimension xold(3,nelec),xnew(3,nelec)

      twopi=2.d0*pi

      do ikx=-NAK2,NAK2
        fkx=delk2*ikx
        do iky=-NAK2,NAK2
          fky=delk2*iky
! first, for old x values:
          sumr_u=0.d0
          sumi_u=0.d0
          sumr_d=0.d0
          sumi_d=0.d0
          sumr_t=0.d0
          sumi_t=0.d0
          do ie=1,nup
            sumr_u=sumr_u+dcos(twopi*(fkx*xold(1,ie)+fky*xold(2,ie)))
            sumi_u=sumi_u+dsin(twopi*(fkx*xold(1,ie)+fky*xold(2,ie)))
          enddo
          do ie=nup+1,nelec
            sumr_d=sumr_d+dcos(twopi*(fkx*xold(1,ie)+fky*xold(2,ie)))
            sumi_d=sumi_d+dsin(twopi*(fkx*xold(1,ie)+fky*xold(2,ie)))
          enddo
          sumr_t=sumr_d+sumr_u
          sumi_t=sumi_d+sumi_u
          fourierkk_u(ikx,iky)=fourierkk_u(ikx,iky)+q*(sumr_u*sumr_u+sumi_u*sumi_u)
          fourierkk_d(ikx,iky)=fourierkk_d(ikx,iky)+q*(sumr_d*sumr_d+sumi_d*sumi_d)
          fourierkk_t(ikx,iky)=fourierkk_t(ikx,iky)+q*(sumr_t*sumr_t+sumi_t*sumi_t)

! now repeat above for new x values:
          sumr_u=0.d0
          sumi_u=0.d0
          sumr_d=0.d0
          sumi_d=0.d0
          sumr_t=0.d0
          sumi_t=0.d0
          do ie=1,nup
            sumr_u=sumr_u+dcos(twopi*(fkx*xnew(1,ie)+fky*xnew(2,ie)))
            sumi_u=sumi_u+dsin(twopi*(fkx*xnew(1,ie)+fky*xnew(2,ie)))
          enddo
          do ie=nup+1,nelec
            sumr_d=sumr_d+dcos(twopi*(fkx*xnew(1,ie)+fky*xnew(2,ie)))
            sumi_d=sumi_d+dsin(twopi*(fkx*xnew(1,ie)+fky*xnew(2,ie)))
          enddo
          sumr_t=sumr_d+sumr_u
          sumi_t=sumi_d+sumi_u
          fourierkk_u(ikx,iky)=fourierkk_u(ikx,iky)+p*(sumr_u*sumr_u+sumi_u*sumi_u)
          fourierkk_d(ikx,iky)=fourierkk_d(ikx,iky)+p*(sumr_d*sumr_d+sumi_d*sumi_d)
          fourierkk_t(ikx,iky)=fourierkk_t(ikx,iky)+p*(sumr_t*sumr_t+sumi_t*sumi_t)

        enddo
      enddo

      return
      end
