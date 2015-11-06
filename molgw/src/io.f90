!=========================================================================
! This file contains
! the procedures for input and outputs
!=========================================================================
subroutine header()
 use m_definitions
 use m_mpi
 use m_warning,only: issue_warning,msg
 implicit none
 integer           :: values(8) 
 character(len=12) :: chartmp
#ifdef _OPENMP
 integer,external :: OMP_get_max_threads
#endif
!=====

 write(stdout,'(x,70("="))') 
 write(stdout,'(/,/,12x,a,/,/)') ' Welcome to the fascinating world of MOLGW'
 write(stdout,'(x,70("="))') 
 write(stdout,*)

 call date_and_time(VALUES=values)

 write(stdout,'(a,i2.2,a,i2.2,a,i4.4)') ' Today is ',values(2),'/',values(3),'/',values(1)
 write(stdout,'(a,i2.2,a,i2.2)')        ' It is now ',values(5),':',values(6)
 select case(values(5))
 case(03,04,05,06,07)
   write(stdout,*) 'And it is too early to work. Go back to sleep'
 case(22,23,00,01,02)
   write(stdout,*) 'And it is too late to work. Go to bed and have a sleep'
 case(12,13)
   write(stdout,*) 'Go and get some good food'
 case(17)
   write(stdout,*) 'Dont forget to go and get the kids'
 case default
   write(stdout,*) 'And it is perfect time to work'
 end select


 write(stdout,*) 'Compilation options'
#ifdef TD_SP
 call issue_warning('TD-DFT and BSE are using single precision to save memory')
#endif
#ifdef HAVE_LIBXC
#ifndef LIBXC_SVN
 call xc_f90_version(values(1),values(2))
 write(chartmp,'(i2,a,i2)') values(1),'.',values(2)
#else
 call xc_f90_version(values(1),values(2),values(3))
 write(chartmp,'(i2,a,i2,a,i2)') values(1),'.',values(2),'.',values(3)
#endif
 write(stdout,*) 'LIBXC version '//TRIM(chartmp)
#endif
#ifdef _OPENMP
 write(msg,'(i6)') OMP_get_max_threads()
 msg='OPENMP option is activated with threads number'//msg
 call issue_warning(msg)
#endif
#ifdef HAVE_MPI
 call issue_warning('Running with MPI')
#endif
#ifdef HAVE_SCALAPACK
 call issue_warning('Running with SCALAPACK')
#ifndef HAVE_MPI
 call die('Code compiled with SCALAPACK, but without MPI. This is not permitted')
#endif
#endif


end subroutine header


!=========================================================================
subroutine dump_out_occupation(title,nbf,nspin,occupation)
 use m_definitions
 use m_mpi
 implicit none
 character(len=*),intent(in) :: title
 integer,intent(in)          :: nbf,nspin
 real(dp),intent(in)         :: occupation(nbf,nspin)
!=====
 integer :: maxsize
 integer :: istate,ispin
!=====

 write(stdout,'(/,x,a)') TRIM(title)

 if(nspin==2) then
   write(stdout,'(a)') '           spin 1       spin 2 '
 endif
 do istate=1,nbf
   if( ANY(occupation(istate,:) > 0.001_dp) ) maxsize = istate 
 enddo
 maxsize = maxsize + 5

 do istate=1,MIN(nbf,maxsize)
   write(stdout,'(x,i3,2(2(x,f12.5)),2x)') istate,occupation(istate,:)
 enddo
 write(stdout,*)

end subroutine dump_out_occupation


!=========================================================================
subroutine dump_out_energy(title,nbf,nspin,occupation,energy)
 use m_definitions
 use m_mpi
 implicit none
 character(len=*),intent(in) :: title
 integer,intent(in)          :: nbf,nspin
 real(dp),intent(in)         :: occupation(nbf,nspin),energy(nbf,nspin)
!=====
 integer,parameter :: MAXSIZE=300
!=====
 integer  :: istate,ispin
 real(dp) :: spin_fact
!=====

 spin_fact = REAL(-nspin+3,dp)

 write(stdout,'(/,x,a)') TRIM(title)

 if(nspin==1) then
   write(stdout,'(a)') '   #       [Ha]         [eV]      '
 else
   write(stdout,'(a)') '   #              [Ha]                      [eV]      '
   write(stdout,'(a)') '           spin 1       spin 2       spin 1       spin 2'
 endif
 do istate=1,MIN(nbf,MAXSIZE)
   select case(nspin)
   case(1)
     write(stdout,'(x,i3,2(x,f12.5),4x,f8.4)') istate,energy(istate,:),energy(istate,:)*Ha_eV,occupation(istate,:)
   case(2)
     write(stdout,'(x,i3,2(2(x,f12.5)),4x,2(f8.4,2x))') istate,energy(istate,:),energy(istate,:)*Ha_eV,occupation(istate,:)
   end select
   if(istate < nbf) then
     if( ANY( occupation(istate+1,:) < spin_fact/2.0_dp .AND. occupation(istate,:) > spin_fact/2.0 ) ) then 
        if(nspin==1) then
          write(stdout,'(a)') '  -----------------------------'
        else
          write(stdout,'(a)') '  -------------------------------------------------------'
        endif
     endif
   endif
 enddo

 write(stdout,*)

end subroutine dump_out_energy


!=========================================================================
subroutine dump_out_matrix(print_matrix,title,n,nspin,matrix)
 use m_definitions
 use m_mpi
 implicit none
 logical,intent(in)          :: print_matrix       
 character(len=*),intent(in) :: title
 integer,intent(in)          :: n,nspin
 real(dp),intent(in)         :: matrix(n,n,nspin)
!=====
 integer,parameter :: MAXSIZE=25
!=====
 integer :: i,ispin
!=====

 if( .NOT. print_matrix ) return

 write(stdout,'(/,x,a)') TRIM(title)

 do ispin=1,nspin
   if(nspin==2) then
     write(stdout,'(a,i1)') ' spin polarization # ',ispin
   endif
   do i=1,MIN(n,MAXSIZE)
     write(stdout,'(x,i3,100(x,f12.5))') i,matrix(i,1:MIN(n,MAXSIZE),ispin)
   enddo
   write(stdout,*)
 enddo
 write(stdout,*)

end subroutine dump_out_matrix


!=========================================================================
subroutine output_homolumo(nbf,nspin,occupation,energy,homo,lumo)
 use m_definitions
 use m_mpi
 implicit none
 integer,intent(in)  :: nbf,nspin
 real(dp),intent(in) :: occupation(nbf,nspin),energy(nbf,nspin)
 real(dp),intent(out) :: homo(nspin),lumo(nspin)
 real(dp) :: homo_tmp,lumo_tmp
 integer :: ispin,ibf


 do ispin=1,nspin
   homo_tmp=-1.d+5
   lumo_tmp= 1.d+5
   do ibf=1,nbf
     if(occupation(ibf,ispin)>completely_empty) then
       homo_tmp = MAX( homo_tmp , energy(ibf,ispin) )
     endif

     if(occupation(ibf,ispin)<1.0_dp - completely_empty ) then
       lumo_tmp = MIN( lumo_tmp , energy(ibf,ispin) )
     endif

   enddo
   homo(ispin) = homo_tmp
   lumo(ispin) = lumo_tmp
 enddo


 write(stdout,*)
 write(stdout,'(a,2(3x,f12.6))') ' HOMO energy    [eV]:',homo(:) * Ha_eV
 write(stdout,'(a,2(3x,f12.6))') ' LUMO energy    [eV]:',lumo(:) * Ha_eV
 write(stdout,'(a,2(3x,f12.6))') ' HOMO-LUMO gap  [eV]:',( lumo(:)-homo(:) ) * Ha_eV
 write(stdout,*)


end subroutine output_homolumo


!=========================================================================
subroutine mulliken_pdos(basis,s_matrix,c_matrix,occupation,energy)
 use m_definitions
 use m_mpi
 use m_inputparam, only: nspin
 use m_atoms
 use m_basis_set
 implicit none
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: s_matrix(basis%nbf,basis%nbf)
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin)
 real(dp),intent(in)        :: occupation(basis%nbf,nspin),energy(basis%nbf,nspin)
!=====
 integer                    :: ibf,ibf_cart,li,ni,ni_cart
 integer                    :: natom1,natom2,istate,ispin
 logical                    :: file_exists
 integer                    :: pdosfile
 real(dp)                   :: proj_state_i(0:basis%ammax),proj_charge
 real(dp)                   :: cs_vector_i(basis%nbf)
 integer                    :: iatom_ibf(basis%nbf)
 integer                    :: li_ibf(basis%nbf)
!=====

 write(stdout,*)
 write(stdout,*) 'Projecting wavefunctions on selected atoms'
 inquire(file='manual_pdos',exist=file_exists)
 if(file_exists) then
   write(stdout,*) 'Opening file:','manual_pdos'
   open(newunit=pdosfile,file='manual_pdos',status='old')
   read(pdosfile,*) natom1,natom2
   close(pdosfile)
 else
   natom1=1
   natom2=1
 endif
 write(stdout,'(a,i5,2x,i5)') ' Range of atoms considered: ',natom1,natom2

 ibf_cart = 1
 ibf      = 1
 do while(ibf_cart<=basis%nbf_cart)
   li      = basis%bf(ibf_cart)%am
   ni_cart = number_basis_function_am('CART',li)
   ni      = number_basis_function_am(basis%gaussian_type,li)

   iatom_ibf(ibf:ibf+ni-1) = basis%bf(ibf_cart)%iatom
   li_ibf(ibf:ibf+ni-1) = li

   ibf      = ibf      + ni
   ibf_cart = ibf_cart + ni_cart
 enddo
 

 write(stdout,*) '==========================================='
 write(stdout,*) ' spin state  energy(eV)  Mulliken proj.'
 proj_charge = 0.0_dp
 do ispin=1,nspin
   do istate=1,basis%nbf
     proj_state_i(:) = 0.0_dp

     cs_vector_i(:) = MATMUL( c_matrix(:,istate,ispin) , s_matrix(:,:) )

     do ibf=1,basis%nbf
       if( iatom_ibf(ibf) >= natom1 .AND. iatom_ibf(ibf) <= natom2 ) then
         li = li_ibf(ibf)
         proj_state_i(li) = proj_state_i(li) + c_matrix(ibf,istate,ispin) * cs_vector_i(ibf)
       endif
     enddo
     proj_charge = proj_charge + occupation(istate,ispin) * SUM(proj_state_i(:))

     write(stdout,'(i3,x,i5,x,20(f16.6,4x))') ispin,istate,energy(istate,ispin)*Ha_eV,&
          SUM(proj_state_i(:)),proj_state_i(:)
   enddo
 enddo
 write(stdout,*) '==========================================='
 write(stdout,'(a,f12.6)') ' Total Mulliken charge: ',proj_charge


end subroutine mulliken_pdos


!=========================================================================
subroutine plot_wfn(basis,c_matrix)
 use m_definitions
 use m_mpi
 use m_inputparam, only: nspin
 use m_atoms
 use m_basis_set
 implicit none
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin)
!=====
 integer,parameter          :: nr=2000
 real(dp),parameter         :: length=10.0_dp
 integer                    :: ir,ibf
 integer                    :: istate1,istate2,istate,ispin
 real(dp)                   :: rr(3)
 real(dp),allocatable       :: phi(:,:),phase(:,:)
 real(dp)                   :: u(3),a(3)
 logical                    :: file_exists
 real(dp)                   :: xxmin,xxmax
 real(dp)                   :: basis_function_r(basis%nbf)
 integer                    :: ibf_cart,ni_cart,ni,li,i_cart
 real(dp),allocatable       :: basis_function_r_cart(:)
 integer                    :: wfrfile
!=====

 write(stdout,*) 
 write(stdout,*) 'Plotting some selected wavefunctions'
 inquire(file='manual_plotwfn',exist=file_exists)
 if(file_exists) then
   open(newunit=wfrfile,file='manual_plotwfn',status='old')
   read(wfrfile,*) istate1,istate2
   read(wfrfile,*) u(:)
   read(wfrfile,*) a(:)
   close(wfrfile)
 else
   istate1=1
   istate2=2
   u(:)=0.0_dp
   u(1)=1.0_dp
   a(:)=0.0_dp
 endif
 u(:) = u(:) / SQRT(SUM(u(:)**2))
 allocate(phase(istate1:istate2,nspin),phi(istate1:istate2,nspin))
 write(stdout,'(a,2(2x,i4))')   ' states:   ',istate1,istate2
 write(stdout,'(a,3(2x,f8.3))') ' direction:',u(:)
 write(stdout,'(a,3(2x,f8.3))') ' origin:   ',a(:)

 xxmin = MINVAL( u(1)*x(1,:) + u(2)*x(2,:) + u(3)*x(3,:) ) - length
 xxmax = MAXVAL( u(1)*x(1,:) + u(2)*x(2,:) + u(3)*x(3,:) ) + length

 phase(:,:)=1.0_dp

 do ir=1,nr
   rr(:) = ( xxmin + (ir-1)*(xxmax-xxmin)/REAL(nr-1,dp) ) * u(:) + a(:)

   phi(:,:) = 0.0_dp
   
   !
   ! First precalculate all the needed basis function evaluations at point rr
   !
   ibf_cart = 1
   ibf      = 1
   do while(ibf_cart<=basis%nbf_cart)
     li      = basis%bf(ibf_cart)%am
     ni_cart = number_basis_function_am('CART',li)
     ni      = number_basis_function_am(basis%gaussian_type,li)

     allocate(basis_function_r_cart(ni_cart))

     do i_cart=1,ni_cart
       basis_function_r_cart(i_cart) = eval_basis_function(basis%bf(ibf_cart+i_cart-1),rr)
     enddo
     basis_function_r(ibf:ibf+ni-1) = MATMUL(  basis_function_r_cart(:) , cart_to_pure(li)%matrix(:,:) )
     deallocate(basis_function_r_cart)

     ibf      = ibf      + ni
     ibf_cart = ibf_cart + ni_cart
   enddo
   !
   ! Precalculation done!
   !

   do ispin=1,nspin
     phi(istate1:istate2,ispin) = MATMUL( basis_function_r(:) , c_matrix(:,istate1:istate2,ispin) )
   enddo

   !
   ! turn the wfns so that they are all positive at a given point
   if(ir==1) then
     do ispin=1,nspin
       do istate=istate1,istate2
         if( phi(istate,ispin) < 0.0_dp ) phase(istate,ispin) = -1.0_dp
       enddo
     enddo
   endif

   write(101,'(50(e16.8,2x))') DOT_PRODUCT(rr(:),u(:)),phi(:,:)*phase(:,:)
   write(102,'(50(e16.8,2x))') DOT_PRODUCT(rr(:),u(:)),phi(:,:)**2

 enddo

 deallocate(phase,phi)

end subroutine plot_wfn


!=========================================================================
subroutine plot_rho(basis,occupation,c_matrix)
 use m_definitions
 use m_mpi
 use m_atoms
 use m_inputparam, only: nspin
 use m_basis_set
 implicit none
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: occupation(basis%nbf,nspin)
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin)
!=====
 integer,parameter          :: nr=2000
 real(dp),parameter         :: length=2.0_dp
 integer                    :: ir,ibf
 integer                    :: istate1,istate2,istate,ispin
 real(dp)                   :: rr(3)
 real(dp),allocatable       :: phi(:,:)
 real(dp)                   :: u(3),a(3)
 logical                    :: file_exists
 real(dp)                   :: xxmin,xxmax
 real(dp)                   :: basis_function_r(basis%nbf)
 integer                    :: ibf_cart,ni_cart,ni,li,i_cart
 real(dp),allocatable       :: basis_function_r_cart(:)
 integer                    :: rhorfile
!=====

 write(stdout,*) 'Plotting the density'
 inquire(file='manual_plotrho',exist=file_exists)
 if(file_exists) then
   open(newunit=rhorfile,file='manual_plotrho',status='old')
   read(rhorfile,*) u(:)
   read(rhorfile,*) a(:)
   close(rhorfile)
 else
   u(:)=0.0_dp
   u(1)=1.0_dp
   a(:)=0.0_dp
 endif
 u(:) = u(:) / SQRT(SUM(u(:)**2))
 allocate(phi(basis%nbf,nspin))
 write(stdout,'(a,3(2x,f8.3))') ' direction:',u(:)
 write(stdout,'(a,3(2x,f8.3))') ' origin:   ',a(:)

 xxmin = MINVAL( u(1)*x(1,:) + u(2)*x(2,:) + u(3)*x(3,:) ) - length
 xxmax = MAXVAL( u(1)*x(1,:) + u(2)*x(2,:) + u(3)*x(3,:) ) + length


 do ir=1,nr
   rr(:) = ( xxmin + (ir-1)*(xxmax-xxmin)/REAL(nr-1,dp) ) * u(:) + a(:)

   phi(:,:) = 0.0_dp
   
   !
   ! First precalculate all the needed basis function evaluations at point rr
   !
   ibf_cart = 1
   ibf      = 1
   do while(ibf_cart<=basis%nbf_cart)
     li      = basis%bf(ibf_cart)%am
     ni_cart = number_basis_function_am('CART',li)
     ni      = number_basis_function_am(basis%gaussian_type,li)

     allocate(basis_function_r_cart(ni_cart))

     do i_cart=1,ni_cart
       basis_function_r_cart(i_cart) = eval_basis_function(basis%bf(ibf_cart+i_cart-1),rr)
     enddo
     basis_function_r(ibf:ibf+ni-1) = MATMUL(  basis_function_r_cart(:) , cart_to_pure(li)%matrix(:,:) )
     deallocate(basis_function_r_cart)

     ibf      = ibf      + ni
     ibf_cart = ibf_cart + ni_cart
   enddo
   !
   ! Precalculation done!
   !

   do ispin=1,nspin
     phi(:,ispin) = MATMUL( basis_function_r(:) , c_matrix(:,:,ispin) )
   enddo

   write(103,'(50(e16.8,2x))') DOT_PRODUCT(rr(:),u(:)),SUM( phi(:,:)**2 * occupation(:,:) )

 enddo

 deallocate(phi)

end subroutine plot_rho


!=========================================================================
subroutine plot_cube_wfn(basis,c_matrix)
 use m_definitions
 use m_mpi
 use m_inputparam, only: nspin
 use m_atoms
 use m_basis_set
 implicit none
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin)
!=====
 integer                    :: nx
 integer                    :: ny
 integer                    :: nz
 real(dp),parameter         :: length=4.0_dp
 integer                    :: ibf
 integer                    :: istate1,istate2,istate,ispin
 real(dp)                   :: rr(3)
 real(dp),allocatable       :: phi(:,:),phase(:,:)
 real(dp)                   :: u(3),a(3)
 logical                    :: file_exists
 real(dp)                   :: xxmin,xxmax,ymin,ymax,zmin,zmax
 real(dp)                   :: basis_function_r(basis%nbf)
 integer                    :: ix,iy,iz,iatom
 integer                    :: ibf_cart,ni_cart,ni,li,i_cart
 real(dp),allocatable       :: basis_function_r_cart(:)
 integer,allocatable        :: ocubefile(:,:)
 character(len=200)         :: file_name
 integer                    :: icubefile
!=====

 if( .NOT. is_iomaster ) return

 write(stdout,*) 
 write(stdout,*) 'Plotting some selected wavefunctions in a cube file'
 inquire(file='manual_cubewfn',exist=file_exists)
 if(file_exists) then
   open(newunit=icubefile,file='manual_cubewfn',status='old')
   read(icubefile,*) istate1,istate2
   read(icubefile,*) nx,ny,nz
   close(icubefile)
 else
   istate1=1
   istate2=2
   nx=40
   ny=40
   nz=40
 endif
 allocate(phase(istate1:istate2,nspin),phi(istate1:istate2,nspin))
 write(stdout,'(a,2(2x,i4))')   ' states:   ',istate1,istate2

 xxmin = MINVAL( x(1,:) ) - length
 xxmax = MAXVAL( x(1,:) ) + length
 ymin = MINVAL( x(2,:) ) - length
 ymax = MAXVAL( x(2,:) ) + length
 zmin = MINVAL( x(3,:) ) - length
 zmax = MAXVAL( x(3,:) ) + length

 allocate(ocubefile(istate1:istate2,nspin))

 do istate=istate1,istate2
   do ispin=1,nspin
     write(file_name,'(a,i3.3,a,i1,a)') 'wfn_',istate,'_',ispin,'.cube'
     open(newunit=ocubefile(istate,ispin),file=file_name)
     write(ocubefile(istate,ispin),'(a)') 'cube file generated from MOLGW'
     write(ocubefile(istate,ispin),'(a,i4)') 'wavefunction ',istate1
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') natom,xxmin,ymin,zmin
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') nx,(xxmax-xxmin)/REAL(nx,dp),0.,0.
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') ny,0.,(ymax-ymin)/REAL(ny,dp),0.
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') nz,0.,0.,(zmax-zmin)/REAL(nz,dp)
     do iatom=1,natom
       write(ocubefile(istate,ispin),'(i6,4(2x,f12.6))') NINT(zatom(iatom)),0.0,x(:,iatom)
     enddo
   enddo
 enddo

 phase(:,:)=1.0_dp

 do ix=1,nx
   rr(1) = ( xxmin + (ix-1)*(xxmax-xxmin)/REAL(nx,dp) ) 
   do iy=1,ny
     rr(2) = ( ymin + (iy-1)*(ymax-ymin)/REAL(ny,dp) ) 
     do iz=1,nz
       rr(3) = ( zmin + (iz-1)*(zmax-zmin)/REAL(nz,dp) ) 


       phi(:,:) = 0.0_dp
       
       !
       ! First precalculate all the needed basis function evaluations at point rr
       !
       ibf_cart = 1
       ibf      = 1
       do while(ibf_cart<=basis%nbf_cart)
         li      = basis%bf(ibf_cart)%am
         ni_cart = number_basis_function_am('CART',li)
         ni      = number_basis_function_am(basis%gaussian_type,li)
    
         allocate(basis_function_r_cart(ni_cart))
    
         do i_cart=1,ni_cart
           basis_function_r_cart(i_cart) = eval_basis_function(basis%bf(ibf_cart+i_cart-1),rr)
         enddo
         basis_function_r(ibf:ibf+ni-1) = MATMUL(  basis_function_r_cart(:) , cart_to_pure(li)%matrix(:,:) )
         deallocate(basis_function_r_cart)
    
         ibf      = ibf      + ni
         ibf_cart = ibf_cart + ni_cart
       enddo
       !
       ! Precalculation done!
       !

       do ispin=1,nspin
         phi(istate1:istate2,ispin) = MATMUL( basis_function_r(:) , c_matrix(:,istate1:istate2,ispin) )
       enddo

       !
       ! turn the wfns so that they are all positive at a given point
       if(iz==1) then
         do ispin=1,nspin
           do istate=istate1,istate2
             if( phi(istate,ispin) < 0.0_dp ) phase(istate,ispin) = -1.0_dp
           enddo
         enddo
       endif

       do istate=istate1,istate2
         do ispin=1,nspin
           write(ocubefile(istate,ispin),'(50(e16.8,2x))') phi(istate,ispin)*phase(istate,ispin)
         enddo
       enddo

     enddo
   enddo
 enddo

 deallocate(phase,phi)

 do istate=istate1,istate2
   do ispin=1,nspin
     close(ocubefile(istate,ispin))
   enddo
 enddo

end subroutine plot_cube_wfn


!=========================================================================
subroutine write_energy_qp(nspin,nbf,energy_qp)
 use m_definitions
 use m_mpi
 implicit none

 integer,intent(in)  :: nspin,nbf
 real(dp),intent(in) :: energy_qp(nbf,nspin)
!=====
 integer           :: energy_qpfile
 integer           :: istate
!=====

 write(stdout,'(/,a)') ' Writing ENERGY_QP file'
 open(newunit=energy_qpfile,file='ENERGY_QP',form='formatted')
 write(energy_qpfile,*) nspin
 write(energy_qpfile,*) nbf
 do istate=1,nbf
   write(energy_qpfile,*) istate,energy_qp(istate,:)
 enddo

 close(energy_qpfile)

end subroutine write_energy_qp


!=========================================================================
subroutine read_energy_qp(nspin,nbf,energy_qp,reading_status)
 use m_definitions
 use m_mpi
 use m_warning,only: issue_warning
 implicit none

 integer,intent(in)   :: nspin,nbf
 integer,intent(out)  :: reading_status
 real(dp),intent(out) :: energy_qp(nbf,nspin)
!=====
 integer           :: energy_qpfile
 integer           :: istate,jstate
 integer           :: nspin_read,nbf_read
 logical           :: file_exists_capitalized,file_exists
!=====

 write(stdout,'(/,a)') ' Reading ENERGY_QP file'

 inquire(file='ENERGY_QP',exist=file_exists_capitalized)
 inquire(file='energy_qp',exist=file_exists)

 if(file_exists_capitalized) then
   open(newunit=energy_qpfile,file='ENERGY_QP',form='formatted',status='old')
 else if(file_exists) then
   open(newunit=energy_qpfile,file='energy_qp',form='formatted',status='old')
 endif

 if( file_exists_capitalized .OR. file_exists ) then
   read(energy_qpfile,*) nspin_read
   read(energy_qpfile,*) nbf_read
   if( nbf_read /= nbf .OR. nspin_read /= nspin ) then
     call issue_warning('ENERGY_QP file does not have the correct dimensions')
     reading_status=2
   else
     do istate=1,nbf
       read(energy_qpfile,*) jstate,energy_qp(istate,:)
       ! Scissor operator
       if( jstate == -1 ) then
         reading_status=-1
         close(energy_qpfile)
         return
       endif
     enddo
     reading_status=0
   endif
   close(energy_qpfile)
 else
   reading_status=1
   call issue_warning('files ENERGY_QP and energy_qp do not exist')
 endif


end subroutine read_energy_qp


!=========================================================================
!TODO remove the subroutine
subroutine write_small_restart(nbf,occupation,c_matrix)
 use m_definitions
 use m_mpi
 use m_inputparam
 implicit none

 integer,intent(in)  :: nbf
 real(dp),intent(in) :: occupation(nbf,nspin)
 real(dp),intent(in) :: c_matrix(nbf,nbf,nspin)
!=====
 integer             :: restartfile
 integer             :: ispin,istate
 integer             :: nstate(2)
!=====

 call start_clock(timing_restart_file)
 write(stdout,'(/,a)') ' Writing a small RESTART file'
 !
 ! Only write down the "occupied states" to save I-O
 nstate(:)=0
 do ispin=1,nspin
   do istate=1,nbf
     if( occupation(istate,ispin) > completely_empty ) nstate(ispin) = istate
   enddo
 enddo
 open(newunit=restartfile,file='RESTART',form='unformatted')
 write(restartfile) calc_type%scf_name
 write(restartfile) nspin
 write(restartfile) nbf
 write(restartfile) nstate(1),nstate(nspin)
 do ispin=1,nspin
   do istate=1,nstate(ispin)
     write(restartfile) c_matrix(:,istate,ispin)
   enddo
 enddo

 close(restartfile)
 call stop_clock(timing_restart_file)

end subroutine write_small_restart


!=========================================================================
!TODO remove the subroutine
subroutine write_big_restart(basis,occupation,c_matrix,energy,hamiltonian_hartree,hamiltonian_exx,hamiltonian_xc)
 use m_definitions
 use m_mpi
 use m_inputparam
 implicit none

 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: occupation(basis%nbf,nspin)
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin),energy(basis%nbf,nspin)
 real(dp),intent(in)        :: hamiltonian_hartree(basis%nbf,basis%nbf)
 real(dp),intent(in)        :: hamiltonian_exx(basis%nbf,basis%nbf,nspin)
 real(dp),intent(in)        :: hamiltonian_xc (basis%nbf,basis%nbf,nspin)
!=====
 integer                    :: restartfile
 integer                    :: ispin,istate,ibf
!=====

 call start_clock(timing_restart_file)
 write(stdout,'(/,a)') ' Writing a big RESTART file'
 open(newunit=restartfile,file='RESTART',form='unformatted')
 write(restartfile) calc_type%scf_name
 write(restartfile) nspin
 write(restartfile) basis%nbf
 write(restartfile) basis%nbf,basis%nbf
 do ispin=1,nspin
   do istate=1,basis%nbf
     write(restartfile) c_matrix(:,istate,ispin)
   enddo
 enddo
 do ispin=1,nspin
   do istate=1,basis%nbf
     write(restartfile) energy(istate,ispin)
   enddo
 enddo
 do ispin=1,nspin
   do ibf=1,basis%nbf
     write(restartfile) hamiltonian_exx(:,ibf,ispin)
   enddo
 enddo
 do ispin=1,nspin
   do ibf=1,basis%nbf
     write(restartfile) hamiltonian_xc(:,ibf,ispin)
   enddo
 enddo
 do ibf=1,basis%nbf
   write(restartfile) hamiltonian_hartree(:,ibf)
 enddo

 call write_basis_set(restartfile,basis)

 close(restartfile)
 call stop_clock(timing_restart_file)

end subroutine write_big_restart


!=========================================================================
subroutine write_restart(restart_type,basis,occupation,c_matrix,energy,hamiltonian_hartree,hamiltonian_exx,hamiltonian_xc)
 use m_definitions
 use m_mpi
 use m_inputparam
 use m_atoms
 implicit none

 integer,intent(in)         :: restart_type
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: occupation(basis%nbf,nspin)
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin),energy(basis%nbf,nspin)
 real(dp),intent(in)        :: hamiltonian_hartree(basis%nbf,basis%nbf)
 real(dp),intent(in)        :: hamiltonian_exx(basis%nbf,basis%nbf,nspin)
 real(dp),intent(in)        :: hamiltonian_xc (basis%nbf,basis%nbf,nspin)
!=====
 integer,parameter          :: restart_version=201510
 integer                    :: restartfile
 integer                    :: ispin,istate,ibf,nstate
!=====

 call start_clock(timing_restart_file)
 
 select case(restart_type)
 case(SMALL_RESTART)
   write(stdout,'(/,a)') ' Writing a small RESTART file'
 case(BIG_RESTART)
   write(stdout,'(/,a)') ' Writing a big RESTART file'
 end select

 open(newunit=restartfile,file='RESTART',form='unformatted',action='write')

 ! An integer to ensure backward compatibility in the future
 write(restartfile) restart_version
 ! RESTART file type SMALL_RESTART=1 or BIG_RESTART=2
 write(restartfile) restart_type
 ! Atomic structure
 write(restartfile) natom
 write(restartfile) zatom(1:natom)
 write(restartfile) x(:,1:natom)
 ! Calculation type
 write(restartfile) calc_type%scf_name
 ! Basis set
 call write_basis_set(restartfile,basis)
 ! Spin channels
 write(restartfile) nspin
 ! Occupations
 write(restartfile) occupation(:,:)
 ! Eigen energies
 write(restartfile) energy(:,:)

 ! Number of states written down in the RESTART file
 if( restart_type == SMALL_RESTART ) then
   ! Identify the highest occupied state in order to
   ! save I-O in SMALL_RESTART
   nstate = 0
   do ispin=1,nspin
     do istate=1,basis%nbf
       if( ANY( occupation(istate,:) > completely_empty ) ) nstate = istate
     enddo
   enddo
 else
   ! Or write down all the states in BIG_RESTART
   nstate = basis%nbf
 endif

 write(restartfile) nstate

 ! Wavefunction coefficients C
 do ispin=1,nspin
   do istate=1,nstate
     write(restartfile) c_matrix(:,istate,ispin)
   enddo
 enddo

 if(restart_type == BIG_RESTART) then

   do ibf=1,basis%nbf
     write(restartfile) hamiltonian_hartree(:,ibf)
   enddo
   do ispin=1,nspin
     do ibf=1,basis%nbf
       write(restartfile) hamiltonian_exx(:,ibf,ispin)
     enddo
   enddo
   do ispin=1,nspin
     do ibf=1,basis%nbf
       write(restartfile) hamiltonian_xc(:,ibf,ispin)
     enddo
   enddo

 endif

 close(restartfile)
 call stop_clock(timing_restart_file)

end subroutine write_restart


!=========================================================================
subroutine read_restart(restart_type,basis,occupation,c_matrix,energy,hamiltonian_hartree,hamiltonian_exx,hamiltonian_xc)
 use m_definitions
 use m_mpi
 use m_inputparam
 use m_atoms
 implicit none

 integer,intent(out)        :: restart_type
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: occupation(basis%nbf,nspin)
 real(dp),intent(out)       :: c_matrix(basis%nbf,basis%nbf,nspin),energy(basis%nbf,nspin)
 real(dp),intent(out)       :: hamiltonian_hartree(basis%nbf,basis%nbf)
 real(dp),intent(out)       :: hamiltonian_exx(basis%nbf,basis%nbf,nspin)
 real(dp),intent(out)       :: hamiltonian_xc (basis%nbf,basis%nbf,nspin)
!=====
 integer                    :: restartfile
 integer                    :: ispin,istate,ibf,nstate
 logical                    :: file_exists,same_scf,same_basis,same_geometry

 integer                    :: restart_version_read
 integer                    :: restart_type_read
 character(len=100)         :: scf_name_read
 integer                    :: natom_read
 real(dp),allocatable       :: zatom_read(:),x_read(:,:)
 type(basis_set)            :: basis_read
 integer                    :: nspin_read
 real(dp),allocatable       :: occupation_read(:,:)
 real(dp),allocatable       :: c_matrix_read(:,:,:)
 real(dp),allocatable       :: hh_read(:,:),hexx_read(:,:,:),hxc_read(:,:,:)
 real(dp),allocatable       :: overlap_mixedbasis(:,:)
 real(dp),allocatable       :: overlap_smallbasis(:,:)
 real(dp),allocatable       :: overlap_bigbasis_approx(:,:)
!=====

 if( ignore_restart_ ) then
   restart_type = NO_RESTART
   return
 endif

 inquire(file='RESTART',exist=file_exists)
 if(.NOT. file_exists) then
   write(stdout,'(/,a)') ' No RESTART file found'
   restart_type = NO_RESTART
   return
 endif


 open(newunit=restartfile,file='RESTART',form='unformatted',status='old',action='read')


 ! An integer to ensure backward compatibility in the future
 read(restartfile) restart_version_read

 if( restart_version_read /= 201510 ) then
   call issue_warning('RESTART file: Version not readable. Skipping the reading')
   restart_type = NO_RESTART
   close(restartfile)
   return
 endif


 ! RESTART file type SMALL_RESTART=1 or BIG_RESTART=2
 read(restartfile) restart_type_read
 if( restart_type_read /= SMALL_RESTART .AND. restart_type_read /= BIG_RESTART ) then
   call issue_warning('RESTART file: Type not readable. Skipping the reading')
   restart_type = NO_RESTART
   close(restartfile)
   return
 endif
 restart_type = restart_type_read


 ! Atomic structure
 read(restartfile) natom_read
 allocate(zatom_read(natom_read),x_read(3,natom_read))
 read(restartfile) zatom_read(1:natom_read)
 read(restartfile) x_read(:,1:natom_read)
 if( natom_read /= natom  &
  .OR. ANY( ABS( zatom_read(:) - zatom(1:natom_read) ) > 1.0e-5_dp ) &
  .OR. ANY( ABS(   x_read(:,:) - x(:,1:natom_read)   ) > 1.0e-5_dp ) ) then
   same_geometry = .FALSE.
   call issue_warning('RESTART file: Geometry has changed')
 else
   same_geometry = .TRUE.
 endif
 deallocate(zatom_read,x_read)


 ! Calculation type
 read(restartfile) scf_name_read
 same_scf = ( TRIM(scf_name_read) == TRIM(calc_type%scf_name) )
 if( .NOT. same_scf) then
   call issue_warning('RESTART file: SCF type has changed')
 endif


 ! Basis set
 call read_basis_set(restartfile,basis_read)
 same_basis = compare_basis_set(basis,basis_read)
 if( .NOT. same_basis) then
   call issue_warning('RESTART file: Basis set has changed')
 endif
 if( basis%gaussian_type /= basis_read%gaussian_type ) then
   write(stdout,*) 'The basis type (cartesian or pure) cannot be changed when restarting from a previous calculation'
   call die('Erase the RESTART file or change the keyword gaussian_type and start the calculation over')
 endif


 ! Spin channels
 read(restartfile) nspin_read
 if( nspin /= nspin_read ) then
   call issue_warning('RESTART file: Number of spin channels has changed')
   call die('not implemented yet')
 endif


 ! Occupations
 allocate(occupation_read(basis_read%nbf,nspin_read))
 read(restartfile) occupation_read(:,:)
 if( ANY( ABS( occupation_read(1:MIN(basis_read%nbf,basis%nbf),:) &
             - occupation(1:MIN(basis_read%nbf,basis%nbf),:) )  > 1.0e-5_dp ) ) then
   call issue_warning('RESTART file: Occupations have changed')
 endif
 deallocate(occupation_read)


 ! Eigen energies
 read(restartfile) energy(1:MIN(basis_read%nbf,basis%nbf),:)
 if( basis_read%nbf < basis%nbf ) then
   energy(basis_read%nbf+1:basis%nbf,:) = 1000.0_dp
 endif
 

 ! Number of states written down in the RESTART file
 read(restartfile) nstate


 ! Wavefunction coefficients C
 allocate(c_matrix_read(basis_read%nbf,nstate,nspin_read))
 do ispin=1,nspin_read
   do istate=1,nstate
     read(restartfile) c_matrix_read(:,istate,ispin)
   enddo
 enddo
 c_matrix(:,:,:) = 0.0_dp
 do ispin=1,nspin_read
   do istate=1,MIN(nstate,basis%nbf)
     c_matrix(1:MIN(basis_read%nbf,basis%nbf),istate,ispin) &
          = c_matrix_read(1:MIN(basis_read%nbf,basis%nbf),istate,ispin)
   enddo
 enddo
 ! Fill the rest of the array with identity
 if( nstate < basis%nbf ) then
   do ispin=1,nspin_read
     do istate=nstate+1,basis%nbf
       c_matrix(istate,istate,ispin) = 1.0_dp
     enddo
   enddo
 endif


 if(restart_type == SMALL_RESTART) then

   close(restartfile)
   return

 else

   allocate(hh_read(basis_read%nbf,basis_read%nbf))
   allocate(hexx_read(basis_read%nbf,basis_read%nbf,nspin_read))
   allocate(hxc_read(basis_read%nbf,basis_read%nbf,nspin_read))

   do ibf=1,basis_read%nbf
     read(restartfile) hh_read(:,ibf)
   enddo
   do ispin=1,nspin_read
     do ibf=1,basis_read%nbf
       read(restartfile) hexx_read(:,ibf,ispin)
     enddo
   enddo
   do ispin=1,nspin_read
     do ibf=1,basis_read%nbf
       read(restartfile) hxc_read(:,ibf,ispin)
     enddo
   enddo

   if( same_basis ) then

     hamiltonian_hartree(:,:) = hh_read(:,:)
     hamiltonian_exx(:,:,:)   = hexx_read(:,:,:)
     hamiltonian_xc(:,:,:)    = hxc_read(:,:,:)

     deallocate(hh_read,hexx_read,hxc_read)
     
     if( same_scf .AND. same_geometry ) then
       restart_type = BIG_RESTART
     else
       restart_type = SMALL_RESTART
     endif
     close(restartfile)
     return

   else

     !
     ! If the basis sets differ, then one needs to transpose the parts of the hamiltonian
     ! for a clever starting point.

     allocate(overlap_smallbasis(basis_read%nbf,basis_read%nbf))
     allocate(overlap_bigbasis_approx(basis%nbf,basis%nbf))
     allocate(overlap_mixedbasis(basis_read%nbf,basis%nbf))

     ! Calculate the overlap matrix of the read basis set, named "smallbasis"
     call setup_overlap_mixedbasis(.FALSE.,basis_read,basis_read,overlap_smallbasis)

     ! Invert the overlap of the read basis set
     call invert(basis_read%nbf,overlap_smallbasis)

     ! Get the scalar products between the old and the new basis sets
     ! Be aware: this is a rectangular matrix
     call setup_overlap_mixedbasis(.FALSE.,basis_read,basis,overlap_mixedbasis)

     !
     ! Evaluate the estimated overlap matrix with the small basis set that is read
     ! in the RESTART file
     ! Since the diagonal of the overlap matrix should be 1 by definition, this
     ! allows us to evaluate how wrong we are and disregard the terms in the
     ! hamiltonian which are poorly evaluated in the small basis set.
     overlap_bigbasis_approx(:,:) = MATMUL( TRANSPOSE( overlap_mixedbasis), MATMUL( overlap_smallbasis , overlap_mixedbasis ) )

     overlap_mixedbasis(:,:) = MATMUL( overlap_smallbasis(:,:)  , overlap_mixedbasis(:,:) )

     hamiltonian_hartree(:,:) = MATMUL( TRANSPOSE(overlap_mixedbasis) , MATMUL( hh_read(:,:), overlap_mixedbasis ) )
     do ispin=1,nspin_read
       hamiltonian_exx(:,:,ispin) = MATMUL( TRANSPOSE(overlap_mixedbasis) , MATMUL( hexx_read(:,:,ispin), overlap_mixedbasis ) )
     enddo
     do ispin=1,nspin_read
       hamiltonian_xc(:,:,ispin) = MATMUL( TRANSPOSE(overlap_mixedbasis) , MATMUL( hxc_read(:,:,ispin), overlap_mixedbasis ) )
     enddo

     !
     ! Disregard the term that are too wrong = evaluated overlap below 0.99 
     ! by giving a huge value to the Hartree
     ! part of the Hamiltonian
     do ibf=1,basis%nbf
       if( ABS(overlap_bigbasis_approx(ibf,ibf) - 1.0_dp ) > 0.010_dp ) then
         hamiltonian_hartree(ibf,ibf)   = 100.0_dp
         hamiltonian_exx    (ibf,ibf,:) = 0.0_dp
         hamiltonian_xc     (ibf,ibf,:) = 0.0_dp
       endif
     enddo
     deallocate(overlap_smallbasis)
     deallocate(overlap_mixedbasis)
     deallocate(overlap_bigbasis_approx)

     restart_type = BASIS_RESTART
     close(restartfile)
     return

   endif


 endif

 ! the code should never reach that point.
 call die('Internal error in the read_restart subroutine')


end subroutine read_restart


!=========================================================================
!TODO remove the subroutine
subroutine read_any_restart(basis,occupation,c_matrix,energy, &
                            hamiltonian_hartree,hamiltonian_exx,hamiltonian_xc,is_restart,is_big_restart,is_basis_restart)
 use m_definitions
 use m_mpi
 use m_warning
 use m_inputparam
 implicit none

 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: occupation(basis%nbf,nspin)
 real(dp),intent(out)       :: c_matrix(basis%nbf,basis%nbf,nspin)
 real(dp),intent(out)       :: energy(basis%nbf,nspin)
 real(dp),intent(out)       :: hamiltonian_hartree(basis%nbf,basis%nbf)
 real(dp),intent(out)       :: hamiltonian_exx(basis%nbf,basis%nbf,nspin)
 real(dp),intent(out)       :: hamiltonian_xc (basis%nbf,basis%nbf,nspin)
 logical,intent(out)        :: is_restart,is_big_restart,is_basis_restart
!=====
 type(basis_set)      :: basis_read
 integer              :: restartfile
 integer              :: ispin,istate,ibf,jbf
 logical              :: file_exists,same_scf_name
 character(len=100)   :: scf_name_read
 integer              :: nspin_read,nbf_read,nstate_read(2)
 real(dp),allocatable :: ham_tmp1(:,:,:),ham_tmp2(:,:,:),ham_tmp3(:,:),overlap_mixedbasis(:,:)
 real(dp),allocatable :: overlap_smallbasis(:,:)
 real(dp),allocatable :: overlap_bigbasis_approx(:,:)
!=====

 is_restart       = .TRUE.
 is_basis_restart = .FALSE.
 is_big_restart   = .FALSE.

 if( ignore_restart_ ) then
   is_restart = .FALSE.
   return
 endif

 inquire(file='RESTART',exist=file_exists)
 if(.NOT. file_exists) then
   write(stdout,'(/,a)') ' No RESTART file found'
   is_restart = .FALSE.
   return
 endif

 open(newunit=restartfile,file='RESTART',form='unformatted',status='old')

 read(restartfile) scf_name_read
 read(restartfile) nspin_read
 read(restartfile) nbf_read

 if( nspin_read /= nspin ) then
   write(stdout,'(/,a)') ' Cannot read the RESTART file: wrong dimensions'
   is_restart = .FALSE.
   close(restartfile)
   return
 else if( nbf_read /= basis%nbf) then
   call issue_warning('Trying to read the RESTART file from a different basis set')
 endif

 same_scf_name = ( TRIM(scf_name_read) == TRIM(calc_type%scf_name) )

 read(restartfile) nstate_read(1),nstate_read(2)

 if( nstate_read(1) == nbf_read .AND. nstate_read(2) == nbf_read     &
    .AND. same_scf_name                                              &
    .AND. .NOT. ignore_bigrestart_ ) then
   call issue_warning('Restart from a big RESTART file obtained within '//TRIM(scf_name_read))
   is_big_restart = .TRUE.
 else
   call issue_warning('Restart from a small RESTART file obtained within '//TRIM(scf_name_read))
   is_big_restart = .FALSE.
 endif
 do ispin=1,nspin
   do istate=1,nstate_read(ispin)
     read(restartfile) c_matrix(1:nbf_read,istate,ispin)
   enddo
 enddo

 if( .NOT. is_big_restart ) then
   close(restartfile)
   return
 endif

 is_big_restart = (nbf_read == basis%nbf)
 is_basis_restart = .NOT. is_big_restart

 do ispin=1,nspin
   do istate=1,nstate_read(ispin)
     read(restartfile) energy(istate,ispin)
   enddo
 enddo

 ! EXX part of the Hamiltonian
 allocate(ham_tmp1(nbf_read,nbf_read,nspin))
 do ispin=1,nspin
   do ibf=1,nbf_read
     read(restartfile) ham_tmp1(:,ibf,ispin)
   enddo
 enddo

 ! XC part of the Hamiltonian
 allocate(ham_tmp2(nbf_read,nbf_read,nspin))
 do ispin=1,nspin
   do ibf=1,nbf_read
     read(restartfile) ham_tmp2(:,ibf,ispin)
   enddo
 enddo

 ! HARTREE part of the Hamiltonian
 allocate(ham_tmp3(nbf_read,nbf_read))
 do ibf=1,nbf_read
   read(restartfile) ham_tmp3(:,ibf)
 enddo

 call read_basis_set(restartfile,basis_read)
 
 if( basis%gaussian_type /= basis_read%gaussian_type ) then
   write(stdout,*) 'The basis type (cartesian or pure) cannot be changed when restarting from a previous calculation'
   call die('Erase the RESTART file or change the keyword gaussian_type and start the calculation over')
 endif

 if( nbf_read /= basis_read%nbf ) then
   write(stdout,*) 'consistency problem in the RESTART file'
   call die('Erase the RESTART file and start the calculation over')
 endif

 hamiltonian_hartree(:,:) = 0.0_dp
 hamiltonian_exx(:,:,:)   = 0.0_dp
 hamiltonian_xc(:,:,:)    = 0.0_dp

 if( is_basis_restart) then
   allocate(overlap_smallbasis(basis_read%nbf,basis_read%nbf))
   allocate(overlap_bigbasis_approx(basis%nbf,basis%nbf))
   allocate(overlap_mixedbasis(basis_read%nbf,basis%nbf))
   call setup_overlap_mixedbasis(.FALSE.,basis_read,basis_read,overlap_smallbasis)
   call invert(basis_read%nbf,overlap_smallbasis)

   call setup_overlap_mixedbasis(.FALSE.,basis_read,basis,overlap_mixedbasis)

   !
   ! Evaluate the estimated overlap matrix with the small basis set that is read
   ! in the RESTART file
   ! Since the diagonal of the overlap matrix should be 1 by definition, this
   ! allows us to evaluate how wrong we are and disregard the terms in the
   ! hamiltonian which are poorly evaluated in the small basis set.
   overlap_bigbasis_approx = MATMUL( TRANSPOSE( overlap_mixedbasis), MATMUL( overlap_smallbasis , overlap_mixedbasis ) )


   overlap_mixedbasis(:,:) = MATMUL( overlap_smallbasis(:,:)  , overlap_mixedbasis(:,:) )

   do ispin=1,nspin
     hamiltonian_exx(:,:,ispin) = MATMUL( TRANSPOSE(overlap_mixedbasis) , MATMUL( ham_tmp1(:,:,ispin), overlap_mixedbasis ) )
   enddo
   do ispin=1,nspin
     hamiltonian_xc(:,:,ispin) = MATMUL( TRANSPOSE(overlap_mixedbasis) , MATMUL( ham_tmp2(:,:,ispin), overlap_mixedbasis ) )
   enddo
   hamiltonian_hartree(:,:) = MATMUL( TRANSPOSE(overlap_mixedbasis) , MATMUL( ham_tmp3, overlap_mixedbasis ) )

   !
   ! Disregard the term that are too wrong by giving a huge value to the Hartree
   ! part of the Hamiltonian
   do ibf=1,basis%nbf
     if( ABS(overlap_bigbasis_approx(ibf,ibf) - 1.0_dp ) > 0.010_dp ) then
       hamiltonian_hartree(ibf,ibf)   = 100.0_dp
       hamiltonian_exx    (ibf,ibf,:) = 0.0_dp
       hamiltonian_xc     (ibf,ibf,:) = 0.0_dp
     endif
   enddo
   deallocate(overlap_smallbasis)
   deallocate(overlap_mixedbasis)
   deallocate(overlap_bigbasis_approx)

 else
 endif

 deallocate(ham_tmp1,ham_tmp2,ham_tmp3)
 close(restartfile)

end subroutine read_any_restart


!=========================================================================
subroutine write_density_grid(basis,p_matrix)
 use m_definitions
 use m_mpi
 use m_timing
 use m_inputparam
 use m_basis_set
 use m_dft_grid
 implicit none

 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: p_matrix(basis%nbf,basis%nbf,nspin)
!=====
 integer  :: densityfile
 integer  :: ispin,igrid
 real(dp) :: basis_function_r(basis%nbf)
 real(dp) :: rr(3),weight
 real(dp) :: rhor_r(nspin)
 real(dp) :: rhor(ngrid,nspin)
!=====


 do igrid=1,ngrid

   rr(:) = rr_grid(:,igrid)
   weight = w_grid(igrid)

   !
   ! Get all the functions at point rr
   call get_basis_functions_r(basis,igrid,basis_function_r)
   call calc_density_r(nspin,basis,p_matrix,rr,basis_function_r,rhor_r)
   rhor(igrid,:) = rhor_r(:)

 enddo

 open(newunit=densityfile,file='DENSITY',form='unformatted')
 write(densityfile) nspin
 write(densityfile) ngrid
 do ispin=1,nspin
   do igrid=1,ngrid,1024
     write(densityfile) rhor(igrid:MIN(igrid+1023,ngrid),ispin)
   enddo
 enddo

end subroutine write_density_grid


!=========================================================================
function evaluate_wfn_r(nspin,basis,c_matrix,istate,ispin,rr)
 use m_definitions
 use m_mpi
 use m_atoms
 use m_basis_set
 implicit none
 integer,intent(in)         :: nspin
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin)
 integer,intent(in)         :: istate,ispin
 real(dp),intent(in)        :: rr(3)
 real(dp)                   :: evaluate_wfn_r
!=====
 integer                    :: ibf_cart,ni_cart,ni,li,i_cart,ibf
 real(dp),allocatable       :: basis_function_r_cart(:)
 real(dp)                   :: basis_function_r(basis%nbf)
!=====



 !
 ! First precalculate all the needed basis function evaluations at point rr
 !
 ibf_cart = 1
 ibf      = 1
 do while(ibf_cart<=basis%nbf_cart)
   li      = basis%bf(ibf_cart)%am
   ni_cart = number_basis_function_am('CART',li)
   ni      = number_basis_function_am(basis%gaussian_type,li)

   allocate(basis_function_r_cart(ni_cart))

   do i_cart=1,ni_cart
     basis_function_r_cart(i_cart) = eval_basis_function(basis%bf(ibf_cart+i_cart-1),rr)
   enddo
   basis_function_r(ibf:ibf+ni-1) = MATMUL(  basis_function_r_cart(:) , cart_to_pure(li)%matrix(:,:) )
   deallocate(basis_function_r_cart)

   ibf      = ibf      + ni
   ibf_cart = ibf_cart + ni_cart
 enddo
 !
 ! Precalculation done!
 !

 evaluate_wfn_r = DOT_PRODUCT( basis_function_r(:) , c_matrix(:,istate,ispin) )


end function evaluate_wfn_r


!=========================================================================
function wfn_parity(basis,c_matrix,istate,ispin)
 use m_definitions
 use m_mpi
 use m_atoms
 use m_basis_set
 use m_inputparam
 implicit none
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin)
 integer,intent(in)         :: istate,ispin
 integer                    :: wfn_parity
!=====
 real(dp) :: phi_tmp1,phi_tmp2,xtmp(3)
 real(dp),external :: evaluate_wfn_r
!=====

 xtmp(1) = xcenter(1) +  2.0_dp
 xtmp(2) = xcenter(2) +  1.0_dp
 xtmp(3) = xcenter(3) +  3.0_dp
 phi_tmp1 = evaluate_wfn_r(nspin,basis,c_matrix,istate,ispin,xtmp)
 xtmp(1) = xcenter(1) -  2.0_dp
 xtmp(2) = xcenter(2) -  1.0_dp
 xtmp(3) = xcenter(3) -  3.0_dp
 phi_tmp2 = evaluate_wfn_r(nspin,basis,c_matrix,istate,ispin,xtmp)

 if( ABS(phi_tmp1 - phi_tmp2)/ABS(phi_tmp1) < 1.0e-6_dp ) then
   wfn_parity = 1
 else
   wfn_parity = -1
 endif
 

end function wfn_parity


!=========================================================================
function wfn_reflection(basis,c_matrix,istate,ispin)
 use m_definitions
 use m_mpi
 use m_atoms
 use m_basis_set
 use m_inputparam
 implicit none
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin)
 integer,intent(in)         :: istate,ispin
 integer                    :: wfn_reflection
!=====
 real(dp) :: phi_tmp1,phi_tmp2,xtmp1(3),xtmp2(3)
 real(dp) :: proj
 real(dp),external :: evaluate_wfn_r
!=====

 xtmp1(1) = x(1,1) +  2.0_dp
 xtmp1(2) = x(2,1) +  1.0_dp
 xtmp1(3) = x(3,1) +  3.0_dp
 phi_tmp1 = evaluate_wfn_r(nspin,basis,c_matrix,istate,ispin,xtmp1)

 proj = DOT_PRODUCT( xtmp1 , xnormal )
 xtmp2(:) = xtmp1(:) -  2.0_dp * proj * xnormal(:)
 phi_tmp2 = evaluate_wfn_r(nspin,basis,c_matrix,istate,ispin,xtmp2)

 if( ABS(phi_tmp1 - phi_tmp2)/ABS(phi_tmp1) < 1.0e-6_dp ) then
   wfn_reflection = 1
 else if( ABS(phi_tmp1 + phi_tmp2)/ABS(phi_tmp1) < 1.0e-6_dp ) then
   wfn_reflection = -1
 else 
   wfn_reflection = 0
 endif


end function wfn_reflection


!=========================================================================
