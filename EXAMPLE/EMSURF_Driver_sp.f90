! “ButterflyPACK” Copyright (c) 2018, The Regents of the University of California, through
! Lawrence Berkeley National Laboratory (subject to receipt of any required approvals from the
! U.S. Dept. of Energy). All rights reserved.

! If you have questions about your rights to use or distribute this software, please contact
! Berkeley Lab's Intellectual Property Office at  IPO@lbl.gov.

! NOTICE.  This Software was developed under funding from the U.S. Department of Energy and the
! U.S. Government consequently retains certain rights. As such, the U.S. Government has been
! granted for itself and others acting on its behalf a paid-up, nonexclusive, irrevocable
! worldwide license in the Software to reproduce, distribute copies to the public, prepare
! derivative works, and perform publicly and display publicly, and to permit other to do so.

! Developers: Yang Liu
!             (Lawrence Berkeley National Lab, Computational Research Division).


! This exmple works with double-complex precision data
#define DAT 2

#include "ButterflyPACK_config.fi"

PROGRAM ButterflyPACK_IE_3D
    use BPACK_DEFS
	use EMSURF_MODULE_SP

	use BPACK_structure
	use BPACK_factor
	use BPACK_constr
	use BPACK_Solve_Mul
	use omp_lib
	use MISC_Utilities
    implicit none

	! include "mkl_vml.fi"

    integer Primary_block, nn, mm,kk,mn,rank,ii,jj
    integer i,j,k, threads_num
	integer seed_myid(50)
	integer times(8)
	real(kind=8) t1,t2

	character(len=:),allocatable  :: string
	character(len=1024)  :: strings,strings1
	character(len=6)  :: info_env
	integer :: length,edge
	integer :: ierr
	integer*8 oldmode,newmode
	type(Hoption)::option
	type(Hstat)::stats
	type(mesh)::msh
	type(Bmatrix)::bmat
	type(kernelquant)::ker
	type(quant_EMSURF),target::quant
	type(proctree)::ptree
	integer,allocatable:: groupmembers(:)
	integer nmpi
	real(kind=8),allocatable::xyz(:,:)
	integer,allocatable::Permutation(:)
	integer Nunk_loc
	integer nargs,flag
	integer v_major,v_minor,v_bugfix

	! nmpi and groupmembers should be provided by the user
	call MPI_Init(ierr)
	call MPI_Comm_size(MPI_Comm_World,nmpi,ierr)
	allocate(groupmembers(nmpi))
	do ii=1,nmpi
		groupmembers(ii)=(ii-1)
	enddo

	call CreatePtree(nmpi,groupmembers,MPI_Comm_World,ptree)
	deallocate(groupmembers)


	if(ptree%MyID==Main_ID)then
    write(*,*) "-------------------------------Program Start----------------------------------"
    write(*,*) "ButterflyPACK_IE_3D"
	call BPACK_GetVersionNumber(v_major,v_minor,v_bugfix)
	write(*,'(A23,I1,A1,I1,A1,I1,A1)') " ButterflyPACK Version:",v_major,".",v_minor,".",v_bugfix
    write(*,*) "   "
	endif

	!**** initialize stats and option
	call InitStat(stats)
	call SetDefaultOptions(option)


	!**** intialize the user-defined derived type quant
	! compute the quadrature rules
    quant%integral_points=6
    allocate (quant%ng1(quant%integral_points), quant%ng2(quant%integral_points), quant%ng3(quant%integral_points), quant%gauss_w(quant%integral_points))
    call gauss_points(quant)

    !*************************input******************************
	quant%DATA_DIR='../EXAMPLE/EM3D_DATA/sphere_2300'

	quant%mesh_normal=1
	quant%scaling=1d0
	quant%wavelength=2.0
	quant%freq=1/quant%wavelength/sqrt(BPACK_mu0*BPACK_eps0)
	quant%RCS_static=2
    quant%RCS_Nsample=1000
	quant%CFIE_alpha=1.0

	option%ErrSol=1
	option%format=  HODLR !HMAT!
	option%near_para=2.01d0
	option%verbosity=1
	option%ILU=0
	option%forwardN15flag=0
	option%LRlevel=100
	option%tol_itersol=1d-5
	option%sample_para=4d0
	option%knn=50

	nargs = iargc()
	ii=1
	do while(ii<=nargs)
		call getarg(ii,strings)
		if(trim(strings)=='-quant')then ! user-defined quantity parameters
			flag=1
			do while(flag==1)
				ii=ii+1
				if(ii<=nargs)then
					call getarg(ii,strings)
					if(strings(1:2)=='--')then
						ii=ii+1
						call getarg(ii,strings1)
						if(trim(strings)=='--data_dir')then
							quant%data_dir=trim(strings1)
						else if	(trim(strings)=='--wavelength')then
							read(strings1,*)quant%wavelength
							quant%freq=1/quant%wavelength/sqrt(BPACK_mu0*BPACK_eps0)
						else if (trim(strings)=='--freq')then
							read(strings1,*)quant%freq
							quant%wavelength=1/quant%freq/sqrt(BPACK_mu0*BPACK_eps0)
						else
							if(ptree%MyID==Main_ID)write(*,*)'ignoring unknown quant: ', trim(strings)
						endif
					else
						flag=0
					endif
				else
					flag=0
				endif
			enddo
		else if(trim(strings)=='-option')then ! options of ButterflyPACK
			call ReadOption(option,ptree,ii)
		else
			if(ptree%MyID==Main_ID)write(*,*)'ignoring unknown argument: ',trim(strings)
			ii=ii+1
		endif
	enddo

    quant%wavenum=2*BPACK_pi/quant%wavelength


   !***********************************************************************
	if(ptree%MyID==Main_ID)then
   write (*,*) ''
   write (*,*) 'EFIE computing'
   write (*,*) 'frequency:',quant%freq
   write (*,*) 'wavelength:',quant%wavelength
   write (*,*) ''
	endif
   !***********************************************************************


	!**** geometry generalization and discretization
	call geo_modeling_SURF(quant,ptree%Comm,quant%DATA_DIR)

	option%touch_para = 3* quant%minedgelength

	!**** register the user-defined function and type in ker
	ker%QuantApp => quant
	ker%FuncZmn => Zelem_EMSURF

	!**** initialization of the construction phase
	t1 = OMP_get_wtime()
	allocate(xyz(3,quant%Nunk))
	do ii=1, quant%Nunk
		xyz(:,ii) = quant%xyz(:,quant%maxnode+ii)
	enddo
    allocate(Permutation(quant%Nunk))
	call PrintOptions(option,ptree)
	call BPACK_construction_Init(quant%Nunk,Permutation,Nunk_loc,bmat,option,stats,msh,ker,ptree,Coordinates=xyz)
	deallocate(Permutation) ! caller can use this permutation vector if needed
	deallocate(xyz)
	t2 = OMP_get_wtime()



	!**** computation of the construction phase
    call BPACK_construction_Element(bmat,option,stats,msh,ker,ptree)



	!**** factorization phase
	call BPACK_Factorization(bmat,option,stats,ptree,msh)


	!**** solve phase
	call EM_solve_SURF(bmat,option,msh,quant,ptree,stats)


	!**** print statistics
	call PrintStat(stats,ptree)


	!**** deletion of quantities
	call delete_quant_EMSURF(quant)
	call delete_proctree(ptree)
	call delete_Hstat(stats)
	call delete_mesh(msh)
	call delete_kernelquant(ker)
	call BPACK_delete(bmat)


    if(ptree%MyID==Main_ID .and. option%verbosity>=0)write(*,*) "-------------------------------program end-------------------------------------"

	call blacs_exit(1)
	call MPI_Finalize(ierr)

    ! ! ! ! pause

end PROGRAM ButterflyPACK_IE_3D






