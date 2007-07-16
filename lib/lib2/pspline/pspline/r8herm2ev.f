      subroutine r8herm2ev(xget,yget,x,nx,y,ny,ilinx,iliny,
     >                   f,inf2,ict,fval,ier)

C  evaluate a 2d cubic Hermite interpolant on a rectilinear
C  grid -- this is C1 in both directions.

C  this subroutine calls two subroutines:
C     herm2xy  -- find cell containing (xget,yget)
C     herm2fcn -- evaluate interpolant function and (optionally) derivatives

C  input arguments:
C  ================

!============
! idecl:  explicitize implicit INTEGER declarations:
      IMPLICIT NONE
c     INTEGER, PARAMETER :: R8=SELECTED_REAL_KIND(12,100)
      INTEGER ny,inf2,nx
!============
      REAL*8 xget,yget                    ! target of this interpolation
      REAL*8 x(nx)                        ! ordered x grid
      REAL*8 y(ny)                        ! ordered y grid
      integer ilinx                     ! ilinx=1 => assume x evenly spaced
      integer iliny                     ! iliny=1 => assume y evenly spaced

      REAL*8 f(0:3,inf2,ny)               ! function data

C       f 2nd dimension inf2 must be .ge. nx
C       contents of f:

C  f(0,i,j) = f @ x(i),y(j)
C  f(1,i,j) = df/dx @ x(i),y(j)
C  f(2,i,j) = df/dy @ x(i),y(j)
C  f(3,i,j) = d2f/dxdy @ x(i),y(j)

      integer ict(4)                    ! code specifying output desired

C  ict(1)=1 -- return f  (0, don't)
C  ict(2)=1 -- return df/dx  (0, don't)
C  ict(3)=1 -- return df/dy  (0, don't)
C  ict(4)=1 -- return d2f/dxdy (0, don't)

C output arguments:
C =================

      REAL*8 fval(4)                      ! output data
      integer ier                       ! error code =0 ==> no error

C  fval(1) receives the first output (depends on ict(...) spec)
C  fval(2) receives the second output (depends on ict(...) spec)
C  fval(3) receives the third output (depends on ict(...) spec)
C  fval(4) receives the fourth output (depends on ict(...) spec)

C  examples:
C    on input ict = [1,1,1,1]
C   on output fval= [f,df/dx,df/dy,d2f/dxdy]

C    on input ict = [1,0,0,0]
C   on output fval= [f] ... elements 2 & 3 & 4 never referenced

C    on input ict = [0,1,1,0]
C   on output fval= [df/dx,df/dy] ... element 3 & 4 never referenced

C    on input ict = [0,0,1,0]
C   on output fval= [df/dy] ... elements 2 & 3 & 4 never referenced.

C  ier -- completion code:  0 means OK
C-------------------
C  local:

      integer i,j                       ! cell indices

C  normalized displacement from (x(i),y(j)) corner of cell.
C    xparam=0 @x(i)  xparam=1 @x(i+1)
C    yparam=0 @y(j)  yparam=1 @y(j+1)

      REAL*8 xparam,yparam

C  cell dimensions and
C  inverse cell dimensions hxi = 1/(x(i+1)-x(i)), hyi = 1/(y(j+1)-y(j))

      REAL*8 hx,hy
      REAL*8 hxi,hyi

C  0 .le. xparam .le. 1
C  0 .le. yparam .le. 1

C---------------------------------------------------------------------

      call r8herm2xy(xget,yget,x,nx,y,ny,ilinx,iliny,
     >   i,j,xparam,yparam,hx,hxi,hy,hyi,ier)
      if(ier.ne.0) return

      call r8herm2fcn(ict,1,1,
     >   fval,i,j,xparam,yparam,hx,hxi,hy,hyi,f,inf2,ny)

      return
      end
C---------------------------------------------------------------------
c  herm2xy -- look up x-y zone

c  this is the "first part" of herm2ev, see comments, above.

      subroutine r8herm2xy(xget,yget,x,nx,y,ny,ilinx,iliny,
     >   i,j,xparam,yparam,hx,hxi,hy,hyi,ier)

c  input of herm2xy
c  ================

!============
! idecl:  explicitize implicit INTEGER declarations:
      IMPLICIT NONE
c     INTEGER, PARAMETER :: R8=SELECTED_REAL_KIND(12,100)
      INTEGER nxm,nym,ii,jj
!============
! idecl:  explicitize implicit REAL declarations:
      REAL*8 zxget,zyget,zxtol,zytol
!============
      integer nx,ny                     ! array dimensions

      REAL*8 xget,yget                    ! target point
      REAL*8 x(nx),y(ny)                  ! indep. coords., strict ascending

      integer ilinx                     ! =1:  x evenly spaced
      integer iliny                     ! =1:  y evenly spaced

c  output of herm2xy
c  =================
      integer i,j                       ! index to cell containing target pt
c          on exit:  1.le.i.le.nx-1   1.le.j.le.ny-1

c  normalized position w/in (i,j) cell (btw 0 and 1):

      REAL*8 xparam                       ! (xget-x(i))/(x(i+1)-x(i))
      REAL*8 yparam                       ! (yget-y(j))/(y(j+1)-y(j))

c  grid spacing

      REAL*8 hx                           ! hx = x(i+1)-x(i)
      REAL*8 hy                           ! hy = y(j+1)-y(j)

c  inverse grid spacing:

      REAL*8 hxi                          ! 1/hx = 1/(x(i+1)-x(i))
      REAL*8 hyi                          ! 1/hy = 1/(y(j+1)-y(j))

      integer ier                       ! return ier.ne.0 on error

c------------------------------------

      ier=0

c  range check

      zxget=xget
      zyget=yget
      if((xget.lt.x(1)).or.(xget.gt.x(nx))) then
         zxtol=4.0D-7*max(abs(x(1)),abs(x(nx)))
         if((xget.lt.x(1)-zxtol).or.(xget.gt.x(nx)+zxtol)) then
            ier=1
            write(6,1001) xget,x(1),x(nx)
 1001       format(' ?herm2ev:  xget=',1pe11.4,' out of range ',
     >         1pe11.4,' to ',1pe11.4)
         else
            if((xget.lt.x(1)-0.5d0*zxtol).or.
     >         (xget.gt.x(nx)+0.5d0*zxtol))
     >      write(6,1011) xget,x(1),x(nx)
 1011       format(' %herm2ev:  xget=',1pe15.8,' beyond range ',
     >         1pe15.8,' to ',1pe15.8,' (fixup applied)')
            if(xget.lt.x(1)) then
               zxget=x(1)
            else
               zxget=x(nx)
            endif
         endif
      endif
      if((yget.lt.y(1)).or.(yget.gt.y(ny))) then
         zytol=4.0D-7*max(abs(y(1)),abs(y(ny)))
         if((yget.lt.y(1)-zytol).or.(yget.gt.y(ny)+zytol)) then
            ier=1
            write(6,1002) yget,y(1),y(ny)
 1002       format(' ?herm2ev:  yget=',1pe11.4,' out of range ',
     >         1pe11.4,' to ',1pe11.4)
         else
            if((yget.lt.y(1)-0.5d0*zytol).or.
     >         (yget.gt.y(ny)+0.5d0*zytol))
     >      write(6,1012) yget,y(1),y(ny)
 1012       format(' %herm2ev:  yget=',1pe15.8,' beyond range ',
     >         1pe15.8,' to ',1pe15.8,' (fixup applied)')
            if(yget.lt.y(1)) then
               zyget=y(1)
            else
               zyget=y(ny)
            endif
         endif
      endif
      if(ier.ne.0) return

c  now find interval in which target point lies..

      nxm=nx-1
      nym=ny-1

      if(ilinx.eq.1) then
         ii=1+nxm*(zxget-x(1))/(x(nx)-x(1))
         i=min(nxm, ii)
         if(zxget.lt.x(i)) then
            i=i-1
         else if(zxget.gt.x(i+1)) then
            i=i+1
         endif
      else
         if((1.le.i).and.(i.lt.nxm)) then
            if((x(i).le.zxget).and.(zxget.le.x(i+1))) then
               continue  ! already have the zone
            else
               call r8zonfind(x,nx,zxget,i)
            endif
         else
            call r8zonfind(x,nx,zxget,i)
         endif
      endif

      if(iliny.eq.1) then
         jj=1+nym*(zyget-y(1))/(y(ny)-y(1))
         j=min(nym, jj)
         if(zyget.lt.y(j)) then
            j=j-1
         else if(zyget.gt.y(j+1)) then
            j=j+1
         endif
      else
         if((1.le.j).and.(j.lt.nym)) then
            if((y(j).le.zyget).and.(zyget.le.y(j+1))) then
               continue  ! already have the zone
            else
               call r8zonfind(y,ny,zyget,j)
            endif
         else
            call r8zonfind(y,ny,zyget,j)
         endif
      endif

      hx=(x(i+1)-x(i))
      hy=(y(j+1)-y(j))

      hxi=1.0d0/hx
      hyi=1.0d0/hy

      xparam=(zxget-x(i))*hxi
      yparam=(zyget-y(j))*hyi

      return
      end
C---------------------------------------------------------------------
C  evaluate C1 cubic Hermite function interpolation -- 2d fcn
C   --vectorized-- dmc 10 Feb 1999

      subroutine r8herm2fcn(ict,ivec,ivecd,
     >   fval,ii,jj,xparam,yparam,hx,hxi,hy,hyi,
     >   fin,inf2,ny)

!============
! idecl:  explicitize implicit INTEGER declarations:
      IMPLICIT NONE
c     INTEGER, PARAMETER :: R8=SELECTED_REAL_KIND(12,100)
      INTEGER ny,inf2,i,j,iadr
!============
! idecl:  explicitize implicit REAL declarations:
      REAL*8 xp,xpi,xp2,xpi2,ax,axbar,bx,bxbar,yp,ypi,yp2,ypi2,ay
      REAL*8 aybar,by,bybar,axp,axbarp,bxp,bxbarp,ayp,aybarp,byp
      REAL*8 bybarp
!============
      integer ict(4)                    ! requested output control
      integer ivec                      ! vector length
      integer ivecd                     ! vector dimension (1st dim of fval)

      integer ii(ivec),jj(ivec)         ! target cells (i,j)
      REAL*8 xparam(ivec),yparam(ivec)
                          ! normalized displacements from (i,j) corners

      REAL*8 hx(ivec),hy(ivec)            ! grid spacing, and
      REAL*8 hxi(ivec),hyi(ivec)          ! inverse grid spacing 1/(x(i+1)-x(i))
                                        ! & 1/(y(j+1)-y(j))

      REAL*8 fin(0:3,inf2,ny)             ! interpolant data (cf "herm2ev")

      REAL*8 fval(ivecd,4)                ! output returned

C  for detailed description of fin, ict and fval see subroutine
C  herm2ev comments.  Note ict is not vectorized; the same output
C  is expected to be returned for all input vector data points.

C  note that the index inputs ii,jj and parameter inputs
C     xparam,yparam,hx,hxi,hy,hyi are vectorized, and the
C     output array fval has a vector ** 1st dimension ** whose
C     size must be given as a separate argument

C  to use this routine in scalar mode, pass in ivec=ivecd=1

C---------------
C  Hermite cubic basis functions
C  -->for function value matching
C     a(0)=0 a(1)=1        a'(0)=0 a'(1)=0
C   abar(0)=1 abar(1)=0  abar'(0)=0 abar'(1)=0

C   a(x)=-2*x**3 + 3*x**2    = x*x*(-2.0*x+3.0)
C   abar(x)=1-a(x)
C   a'(x)=-abar'(x)          = 6.0*x*(1.0-x)

C  -->for derivative matching
C     b(0)=0 b(1)=0          b'(0)=0 b'(1)=1
C   bbar(0)=0 bbar(1)=0  bbar'(0)=1 bbar'(1)=0

C     b(x)=x**3-x**2         b'(x)=3*x**2-2*x
C     bbar(x)=x**3-2*x**2+x  bbar'(x)=3*x**2-4*x+1

      REAL*8 sum
      integer v

C   ...in x direction

      do v=1,ivec
         i=ii(v)
         j=jj(v)
         xp=xparam(v)
         xpi=1.0d0-xp
         xp2=xp*xp
         xpi2=xpi*xpi
         ax=xp2*(3.0d0-2.0d0*xp)
         axbar=1.0d0-ax
         bx=-xp2*xpi
         bxbar=xpi2*xp

C   ...in y direction

         yp=yparam(v)
         ypi=1.0d0-yp
         yp2=yp*yp
         ypi2=ypi*ypi
         ay=yp2*(3.0d0-2.0d0*yp)
         aybar=1.0d0-ay
         by=-yp2*ypi
         bybar=ypi2*yp

C   ...derivatives...

         if((ict(2).eq.1).or.(ict(4).eq.1)) then
            axp=6.0d0*xp*xpi
            axbarp=-axp
            bxp=xp*(3.0d0*xp-2.0d0)
            bxbarp=xpi*(3.0d0*xpi-2.0d0)
         endif

         if((ict(3).eq.1).or.(ict(4).eq.1)) then
            ayp=6.0d0*yp*ypi
            aybarp=-ayp
            byp=yp*(3.0d0*yp-2.0d0)
            bybarp=ypi*(3.0d0*ypi-2.0d0)
         endif

         iadr=0

C  get desired values:

         if(ict(1).eq.1) then

C  function value:

            iadr=iadr+1
            sum=axbar*(aybar*fin(0,i,j)  +ay*fin(0,i,j+1))+
     >             ax*(aybar*fin(0,i+1,j)+ay*fin(0,i+1,j+1))

            sum=sum+hx(v)*(
     >         bxbar*(aybar*fin(1,i,j)  +ay*fin(1,i,j+1))+
     >            bx*(aybar*fin(1,i+1,j)+ay*fin(1,i+1,j+1)))

            sum=sum+hy(v)*(
     >         axbar*(bybar*fin(2,i,j)  +by*fin(2,i,j+1))+
     >            ax*(bybar*fin(2,i+1,j)+by*fin(2,i+1,j+1)))

            sum=sum+hx(v)*hy(v)*(
     >         bxbar*(bybar*fin(3,i,j)  +by*fin(3,i,j+1))+
     >            bx*(bybar*fin(3,i+1,j)+by*fin(3,i+1,j+1)))

            fval(v,iadr)=sum
         endif

         if(ict(2).eq.1) then

C  df/dx:

            iadr=iadr+1

            sum=hxi(v)*(
     >         axbarp*(aybar*fin(0,i,j)  +ay*fin(0,i,j+1))+
     >            axp*(aybar*fin(0,i+1,j)+ay*fin(0,i+1,j+1)))

            sum=sum+
     >         bxbarp*(aybar*fin(1,i,j)  +ay*fin(1,i,j+1))+
     >            bxp*(aybar*fin(1,i+1,j)+ay*fin(1,i+1,j+1))

            sum=sum+hxi(v)*hy(v)*(
     >         axbarp*(bybar*fin(2,i,j)  +by*fin(2,i,j+1))+
     >            axp*(bybar*fin(2,i+1,j)+by*fin(2,i+1,j+1)))

            sum=sum+hy(v)*(
     >         bxbarp*(bybar*fin(3,i,j)  +by*fin(3,i,j+1))+
     >            bxp*(bybar*fin(3,i+1,j)+by*fin(3,i+1,j+1)))

            fval(v,iadr)=sum
         endif

         if(ict(3).eq.1) then

C  df/dy:

            iadr=iadr+1

            sum=hyi(v)*(
     >         axbar*(aybarp*fin(0,i,j)  +ayp*fin(0,i,j+1))+
     >            ax*(aybarp*fin(0,i+1,j)+ayp*fin(0,i+1,j+1)))

            sum=sum+hx(v)*hyi(v)*(
     >         bxbar*(aybarp*fin(1,i,j)  +ayp*fin(1,i,j+1))+
     >            bx*(aybarp*fin(1,i+1,j)+ayp*fin(1,i+1,j+1)))

            sum=sum+
     >         axbar*(bybarp*fin(2,i,j)  +byp*fin(2,i,j+1))+
     >            ax*(bybarp*fin(2,i+1,j)+byp*fin(2,i+1,j+1))

            sum=sum+hx(v)*(
     >         bxbar*(bybarp*fin(3,i,j)  +byp*fin(3,i,j+1))+
     >            bx*(bybarp*fin(3,i+1,j)+byp*fin(3,i+1,j+1)))

            fval(v,iadr)=sum
         endif

         if(ict(4).eq.1) then

C  d2f/dxdy:

            iadr=iadr+1

            sum=hxi(v)*hyi(v)*(
     >         axbarp*(aybarp*fin(0,i,j)  +ayp*fin(0,i,j+1))+
     >            axp*(aybarp*fin(0,i+1,j)+ayp*fin(0,i+1,j+1)))

            sum=sum+hyi(v)*(
     >         bxbarp*(aybarp*fin(1,i,j)  +ayp*fin(1,i,j+1))+
     >            bxp*(aybarp*fin(1,i+1,j)+ayp*fin(1,i+1,j+1)))

            sum=sum+hxi(v)*(
     >         axbarp*(bybarp*fin(2,i,j)  +byp*fin(2,i,j+1))+
     >            axp*(bybarp*fin(2,i+1,j)+byp*fin(2,i+1,j+1)))

            sum=sum+
     >         bxbarp*(bybarp*fin(3,i,j)  +byp*fin(3,i,j+1))+
     >            bxp*(bybarp*fin(3,i+1,j)+byp*fin(3,i+1,j+1))

            fval(v,iadr)=sum
         endif

      enddo                             ! vector loop

      return
      end
