#!/bin/bash
ROOTDIR=$PWD
SRCDIR=$ROOTDIR/SRC
DSRCDIR=$ROOTDIR/SRC_DOUBLE
ZSRCDIR=$ROOTDIR/SRC_DOUBLECOMPLEX

MACRO_FILE=$SRCDIR/ButterflyPACK_config.fi
TMP_FILE=$PWD/tmp.txt
lb="\b"
rb="\b"

major=$(grep "set(VERSION_MAJOR" ./CMakeLists.txt | sed 's/[^"]*"\([^"]*\)".*/\1/')
minor=$(grep "set(VERSION_MINOR" ./CMakeLists.txt | sed 's/[^"]*"\([^"]*\)".*/\1/')
bug=$(grep "set(VERSION_BugFix" ./CMakeLists.txt | sed 's/[^"]*"\([^"]*\)".*/\1/')
sed -i -e "s/BPACK_MAJOR_VERSION.*/BPACK_MAJOR_VERSION = $major/" ./SRC/BPACK_defs.f90
sed -i -e "s/BPACK_MINOR_VERSION.*/BPACK_MINOR_VERSION = $minor/" ./SRC/BPACK_defs.f90
sed -i -e "s/BPACK_PATCH_VERSION.*/BPACK_PATCH_VERSION = $bug/" ./SRC/BPACK_defs.f90


######## The following takes care of windows to linux conversion
declare -a StringArray=("*.*" "SRC/*.*" "EXAMPLE/*.*" "Makefile" "*/Makefile")
for val in ${StringArray[@]}; do
   # echo $val
#   sed -i "s/\r$/\r" $val
   sed -i -e "s/[[:blank:]]*$//" $val
done


# sed -i "s/\r$//" *.*
# sed -i "s/\r$//" SRC/*.*
# sed -i "s/\r$//" EXAMPLE/*.*
# sed -i "s/[[:blank:]]*$//" *.*
# sed -i "s/[[:blank:]]*$//" SRC/*.*
# sed -i "s/[[:blank:]]*$//" EXAMPLE/*.*

############################################################################
echo "-- generating macro definition header ..."
rm -rf $TMP_FILE
rm -rf $MACRO_FILE
grep -h "end subroutine" --include='*.f90' --include='*.c' --include='*.h' $SRCDIR/* |sed "s/[[:blank:]]*$//" | sed "s/.* \([^ ][^ ]*\) */\1/" > $TMP_FILE
grep -h "end function" --include='*.f90' --include='*.c' --include='*.h' $SRCDIR/* |sed "s/[[:blank:]]*$//" | sed "s/.* \([^ ][^ ]*\) */\1/" >> $TMP_FILE
grep -h "end type" --include='*.f90' --include='*.c' --include='*.h' $SRCDIR/* |sed "s/[[:blank:]]*$//" | sed "s/.* \([^ ][^ ]*\) */\1/" >> $TMP_FILE
grep -h "end module" --include='*.f90' --include='*.c' --include='*.h' $SRCDIR/* |sed "s/[[:blank:]]*$//" | sed "s/.* \([^ ][^ ]*\) */\1/" >> $TMP_FILE
> $MACRO_FILE
echo "#ifdef DAT" >> $MACRO_FILE
echo "#if DAT==0" >> $MACRO_FILE
echo " " >> $MACRO_FILE
echo "#define DT complex(kind=8)" >> $MACRO_FILE
echo "#define MPI_DT MPI_DOUBLE_COMPLEX" >> $MACRO_FILE
echo "#define C_SIZEOF_DT sizeof_complex16" >> $MACRO_FILE
echo "#define CBIND_DT complex(kind=C_DOUBLE_COMPLEX)" >> $MACRO_FILE
echo "#define C_DT _Complex double" >> $MACRO_FILE
echo "#define gemmf77 zgemm" >> $MACRO_FILE
echo "#define copymatf77 zlacpy" >> $MACRO_FILE
echo " " >> $MACRO_FILE
while IFS= read -r line ; do
    echo "#define $line z_$line" >> $MACRO_FILE
done < "$TMP_FILE"
echo " " >> $MACRO_FILE
echo "#elif DAT==1" >> $MACRO_FILE
echo " " >> $MACRO_FILE
echo "#define DT real(kind=8)" >> $MACRO_FILE
echo "#define MPI_DT MPI_DOUBLE_PRECISION" >> $MACRO_FILE
echo "#define C_SIZEOF_DT sizeof_double" >> $MACRO_FILE
echo "#define CBIND_DT real(kind=C_DOUBLE)" >> $MACRO_FILE
echo "#define C_DT double" >> $MACRO_FILE
echo "#define gemmf77 dgemm" >> $MACRO_FILE
echo "#define copymatf77 dlacpy" >> $MACRO_FILE
echo " " >> $MACRO_FILE
while IFS= read -r line ; do
    echo "#define $line d_$line" >> $MACRO_FILE
done < "$TMP_FILE"
echo "#endif" >> $MACRO_FILE
echo "#endif" >> $MACRO_FILE
rm -rf $TMP_FILE
cp $MACRO_FILE $ROOTDIR/EXAMPLE/.

###########################################################
# note that module names and *.h headers need to be renamed without macros
echo "-- copy and modify SRC dir ..."
grep -h "end module" --include='*.f90' --include='*.f' $SRCDIR/* |sed "s/[[:blank:]]*$//" | sed "s/.* \([^ ][^ ]*\) */\1/" > $TMP_FILE
rm -rf $ZSRCDIR
cp -r $SRCDIR $ZSRCDIR
while IFS= read -r line; do
    sed -i -e "s/$lb$line$rb/z_$line/g" $ZSRCDIR/*.f90
    sed -i -e "s/$lb$line$rb/z_$line/g" $ZSRCDIR/*.f
    sed -i -e "s/$lb$line$rb/z_$line/g" $ZSRCDIR/*.h
done < "$TMP_FILE"
sed -i -e "s/C_DT/_Complex double /g" $ZSRCDIR/*.h
sed -i -e "s/c_bpack_/z_c_bpack_/g" $ZSRCDIR/*.h
sed -i -e "s/c_bf_/z_c_bf_/g" $ZSRCDIR/*.h
sed -i -e "s/BPACK_WRAP/z_BPACK_WRAP/g" $ZSRCDIR/*.h
sed -i -e "s/c_bpack_/z_c_bpack_/g" $ZSRCDIR/*.f90
sed -i -e "s/c_bf_/z_c_bf_/g" $ZSRCDIR/*.f90
sed -i -e "s/c_magma_offset_1d/z_c_magma_offset_1d/g" $ZSRCDIR/*.f90
sed -i -e "s/c_magma_offset_2d/z_c_magma_offset_2d/g" $ZSRCDIR/*.f90
sed -i -e "s/magmablas_gemm_vbatched/magmablas_zgemm_vbatched/g" $ZSRCDIR/*.f90

rm -rf $DSRCDIR
cp -r $SRCDIR $DSRCDIR
while IFS= read -r line; do
	sed -i -e "s/$lb$line$rb/d_$line/g" $DSRCDIR/*.f90
	sed -i -e "s/$lb$line$rb/d_$line/g" $DSRCDIR/*.f
	sed -i -e "s/$lb$line$rb/d_$line/g" $DSRCDIR/*.h
done < "$TMP_FILE"
sed -i -e "s/C_DT/double/g" $DSRCDIR/*.h
sed -i -e "s/c_bpack_/d_c_bpack_/g" $DSRCDIR/*.h
sed -i -e "s/c_bf_/d_c_bf_/g" $DSRCDIR/*.h
sed -i -e "s/BPACK_WRAP/d_BPACK_WRAP/g" $DSRCDIR/*.h
sed -i -e "s/c_bpack_/d_c_bpack_/g" $DSRCDIR/*.f90
sed -i -e "s/c_bf_/d_c_bf_/g" $DSRCDIR/*.f90
sed -i -e "s/c_magma_offset_1d/d_c_magma_offset_1d/g" $DSRCDIR/*.f90
sed -i -e "s/c_magma_offset_2d/d_c_magma_offset_2d/g" $DSRCDIR/*.f90
sed -i -e "s/magmablas_gemm_vbatched/magmablas_dgemm_vbatched/g" $DSRCDIR/*.f90


###########################################################
echo "-- copy and modify CMakeLists.txt ..."
cd $ZSRCDIR
for file in *; do
	if [ $file != CMakeLists.txt ] && [ $file != ButterflyPACK_config.fi ] && [ $file != Makefile ];
	then
		eval sed -i -e "s/$file/z$file/g" $ZSRCDIR/CMakeLists.txt
		objfile=${file%.*}.o
		eval sed -i -e "s/$objfile/z$objfile/g" $ZSRCDIR/Makefile
		mv "$file" "z${file}"
	fi
done
sed -i -e "s/butterflypack/zbutterflypack/g" $ZSRCDIR/CMakeLists.txt
sed -i -e "s/ButterflyPACKLIB/ZButterflyPACKLIB/g" $ZSRCDIR/Makefile
sed -i -e "s/-DDAT/-DDAT=0/g" $ZSRCDIR/CMakeLists.txt
sed -i -e "s/-DDAT/-DDAT=0/g" $ZSRCDIR/Makefile


cd $DSRCDIR
for file in *; do
	if [ $file != CMakeLists.txt ] && [ $file != ButterflyPACK_config.fi ] && [ $file != Makefile ];
	then
		mv "$file" "d${file}"
		eval sed -i -e "s/$file/d$file/g" $DSRCDIR/CMakeLists.txt
		objfile=${file%.*}.o
		eval sed -i -e "s/$objfile/d$objfile/g" $DSRCDIR/Makefile
	fi
done
sed -i -e "s/butterflypack/dbutterflypack/g" $DSRCDIR/CMakeLists.txt
sed -i -e "s/ButterflyPACKLIB/DButterflyPACKLIB/g" $DSRCDIR/Makefile
sed -i -e "s/-DDAT/-DDAT=1/g" $DSRCDIR/CMakeLists.txt
sed -i -e "s/-DDAT/-DDAT=1/g" $DSRCDIR/Makefile
cd $ROOTDIR
rm -rf $TMP_FILE
rm -rf $MACRO_FILE
