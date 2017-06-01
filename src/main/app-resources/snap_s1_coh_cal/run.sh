#!/bin/bash

# source the ciop functions (e.g. ciop-log, ciop-getparam)
source ${ciop_job_include}

# set the environment variables to use ESA SNAP toolbox
source $_CIOP_APPLICATION_PATH/gpt/snap_include.sh

# define the exit codes
SUCCESS=0
ERR_NODATA=1
SNAP_REQUEST_ERROR=2
ERR_SNAP=3
ERR_NOCOH_WIN_SIZE=4
ERR_COH_WIN_SIZE_NO_INT=5

# add a trap to exit gracefully
function cleanExit ()
{
    local retval=$?
    local msg=""

    case ${retval} in
        ${SUCCESS})               	msg="Processing successfully concluded";;
        ${ERR_NODATA})            	msg="Could not retrieve the input data";;
        ${SNAP_REQUEST_ERROR})    	msg="Could not create snap request file";;
        ${ERR_SNAP})              	msg="SNAP failed to process";;
        ${ERR_NOCOH_WIN_SIZE})    	msg="Coherence window size is empty";;
        ${ERR_COH_WIN_SIZE_NO_INT})     msg="Coherence window size is not an integer";;
        *)                        	msg="Unknown error";;
    esac

   [ ${retval} -ne 0 ] && ciop-log "ERROR" "Error ${retval} - ${msg}, processing aborted" || ciop-log "INFO" "${msg}"
   if [ $DEBUG -ne 1 ] ; then   
	[ ${retval} -ne 0 ] && hadoop dfs -rmr $(dirname "${inputfile}")
   fi
   exit ${retval}
}

trap cleanExit EXIT

function create_snap_request_orb_cal_back_esd() {
	
    # prepare snap request file for calibration processing chain containing:
    # - apply orbit file for both master and slave
    # - calibration of both master and slave
    # - back geocoding
    # - enhanced spectral diversity
    # It returns the path to the request
    # example of function call
    # SNAP_REQUEST=$( create_snap_request_orb_cal_back_esd "${masterSplitted}" "${slaveSplitted}" "${orbitType}" "${demType}" "${outputname_orb_cal_back_esd}" )

	
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "5" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi
	
    local mastername="$1"
    local slavename="$2"
    local orbitType="$3"
    local demType="$4"
    local outputname_orb_cal_back_esd="$5"

    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${mastername}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="Read(2)">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${slavename}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="Apply-Orbit-File">
    <operator>Apply-Orbit-File</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <orbitType>${orbitType}</orbitType>
      <polyDegree>3</polyDegree>
      <continueOnFail>true</continueOnFail>
    </parameters>
  </node>
  <node id="Apply-Orbit-File(2)">
    <operator>Apply-Orbit-File</operator>
    <sources>
      <sourceProduct refid="Read(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <orbitType>${orbitType}</orbitType>
      <polyDegree>3</polyDegree>
      <continueOnFail>true</continueOnFail>
    </parameters>
  </node>
  <node id="Calibration">
    <operator>Calibration</operator>
    <sources>
      <sourceProduct refid="Apply-Orbit-File"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <auxFile>Latest Auxiliary File</auxFile>
      <externalAuxFile/>
      <outputImageInComplex>true</outputImageInComplex>
      <outputImageScaleInDb>false</outputImageScaleInDb>
      <createGammaBand>false</createGammaBand>
      <createBetaBand>false</createBetaBand>
      <selectedPolarisations/>
      <outputSigmaBand>true</outputSigmaBand>
      <outputGammaBand>false</outputGammaBand>
      <outputBetaBand>false</outputBetaBand>
    </parameters>
  </node>
  <node id="Calibration(2)">
    <operator>Calibration</operator>
    <sources>
      <sourceProduct refid="Apply-Orbit-File(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <auxFile>Latest Auxiliary File</auxFile>
      <externalAuxFile/>
      <outputImageInComplex>true</outputImageInComplex>
      <outputImageScaleInDb>false</outputImageScaleInDb>
      <createGammaBand>false</createGammaBand>
      <createBetaBand>false</createBetaBand>
      <selectedPolarisations/>
      <outputSigmaBand>true</outputSigmaBand>
      <outputGammaBand>false</outputGammaBand>
      <outputBetaBand>false</outputBetaBand>
    </parameters>
  </node>
  <node id="Back-Geocoding">
    <operator>Back-Geocoding</operator>
    <sources>
      <sourceProduct refid="Calibration"/>
      <sourceProduct.1 refid="Calibration(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <demName>${demType}</demName>
      <demResamplingMethod>BICUBIC_INTERPOLATION</demResamplingMethod>
      <externalDEMFile/>
      <externalDEMNoDataValue>0.0</externalDEMNoDataValue>
      <resamplingType>BISINC_5_POINT_INTERPOLATION</resamplingType>
      <maskOutAreaWithoutElevation>false</maskOutAreaWithoutElevation>
      <outputRangeAzimuthOffset>false</outputRangeAzimuthOffset>
      <outputDerampDemodPhase>true</outputDerampDemodPhase>
      <disableReramp>false</disableReramp>
    </parameters>
  </node>
  <node id="Enhanced-Spectral-Diversity">
    <operator>Enhanced-Spectral-Diversity</operator>
    <sources>
      <sourceProduct refid="Back-Geocoding"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <fineWinWidthStr>512</fineWinWidthStr>
      <fineWinHeightStr>512</fineWinHeightStr>
      <fineWinAccAzimuth>16</fineWinAccAzimuth>
      <fineWinAccRange>16</fineWinAccRange>
      <fineWinOversampling>128</fineWinOversampling>
      <xCorrThreshold>0.1</xCorrThreshold>
      <cohThreshold>0.15</cohThreshold>
      <numBlocksPerOverlap>10</numBlocksPerOverlap>
      <useSuppliedShifts>false</useSuppliedShifts>
      <overallAzimuthShift>0.0</overallAzimuthShift>
      <overallRangeShift>0.0</overallRangeShift>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="Enhanced-Spectral-Diversity"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputname_orb_cal_back_esd}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
      <displayPosition x="25.0" y="13.0"/>
    </node>
    <node id="Read(2)">
      <displayPosition x="28.0" y="229.0"/>
    </node>
    <node id="Apply-Orbit-File">
      <displayPosition x="12.0" y="84.0"/>
    </node>
    <node id="Apply-Orbit-File(2)">
      <displayPosition x="6.0" y="160.0"/>
    </node>
    <node id="Back-Geocoding">
      <displayPosition x="116.0" y="123.0"/>
    </node>
	<node id="Calibration">
      <displayPosition x="241.0" y="123.0"/>
    </node>
    <node id="Calibration(2)">
      <displayPosition x="427.0" y="123.0"/>
    </node>
    <node id="Enhanced-Spectral-Diversity">
      <displayPosition x="538.0" y="123.0"/>
    </node>
    <node id="Write">
      <displayPosition x="743.0" y="197.0"/>
    </node>
  </applicationData>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}
}


function create_snap_request_coh_deb() {

    # prepare snap request file for coeherence processing chain containing:
    # - coherence computation 
    # - TOPSAR DEBURSTING
    # It returns the path to the request
    # example of function call
    # SNAP_REQUEST=$( create_snap_request_coh_deb "${input_orb_cal_back_esd}" "${cohWinAz}" "${cohWinRg}"  "${outputnameCoherence}" )


    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "4" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi

    local input_orb_cal_back_esd="$1"
    local cohWinAz="$2"
    local cohWinRg="$3"
    local outputnameCoherence="$4"

    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${input_orb_cal_back_esd}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="Coherence">
    <operator>Coherence</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <cohWinAz>${cohWinAz}</cohWinAz>
      <cohWinRg>${cohWinRg}</cohWinRg>
      <subtractFlatEarthPhase>true</subtractFlatEarthPhase>
      <srpPolynomialDegree>5</srpPolynomialDegree>
      <srpNumberPoints>501</srpNumberPoints>
      <orbitDegree>3</orbitDegree>
      <squarePixel>true</squarePixel>
    </parameters>
  </node>
  <node id="TOPSAR-Deburst">
    <operator>TOPSAR-Deburst</operator>
    <sources>
      <sourceProduct refid="Coherence"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations/>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="TOPSAR-Deburst"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputnameCoherence}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}
}

# create function to make deburst the calibrated couple, then save images in separated dim files keeping their amplitude (not longer complex)
function create_snap_request_deb() {

    # prepare snap request file for backscatter processing processing chain containing:
    # - TOPSAR DEBURSTING
    # It returns the path to the request
    # example of function call
    # SNAP_REQUEST=$( create_snap_request_deb "${input_orb_cal_back_esd}" "${outputnameSigma}" )


    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "2" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi

    local input_orb_cal_back_esd="$1"
    local outputnameSigma="$2"

    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${input_orb_cal_back_esd}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="TOPSAR-Deburst">
    <operator>TOPSAR-Deburst</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations/>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="TOPSAR-Deburst"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputnameSigma}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}
}


function main() { 

   local splittedCouple="$1"

   # retrieve the parameters value from workflow or job default value
   orbitType="`ciop-getparam orbittype`"

   # log the value, it helps debugging. 
   # the log entry is available in the process stderr 
   ciop-log "DEBUG" "The Orbit type used is: ${orbitType}" 

   # retrieve the parameters value from workflow or job default value
   demType="`ciop-getparam demtype`"

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The DEM type used is: ${demType}"

   # retrieve the parameters value from workflow or job default value
   cohWinAz="`ciop-getparam cohWinAz`"

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The coeherence azimuth window size is: ${cohWinAz}"

   #check if not empty and integer
   [ -z "${cohWinAz}" ] && exit ${ERR_NOCOH_WIN_SIZE}
  
   re='^[0-9]+$'
   if ! [[ $cohWinAz =~ $re ]] ; then
      exit ${ERR_COH_WIN_SIZE_NO_INT}
   fi

   # retrieve the parameters value from workflow or job default value
   cohWinRg="`ciop-getparam cohWinRg`"

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The coeherence range window size is: ${cohWinRg}"

   #check if not empty and integer
   [ -z "${cohWinRg}" ] && exit ${ERR_NOCOH_WIN_SIZE}

   re='^[0-9]+$'
   if ! [[ $cohWinRg =~ $re ]] ; then
      exit ${ERR_COH_WIN_SIZE_NO_INT}
   fi

   # report activity in log
   ciop-log "INFO" "Retrieving $splittedCouple from storage"

   retrieved=$( ciop-copy -U -o $INPUTDIR "$splittedCouple" )
   # check if the file was retrieved, if not exit with the error code $ERR_NODATA
   [ $? -eq 0 ] && [ -e "${retrieved}" ] || return ${ERR_NODATA}

   # report activity in the log
   ciop-log "INFO" "Retrieved ${retrieved}"
   
   cd $INPUTDIR
   unzip `basename ${retrieved}` &> /dev/null
   # let's check the return value
   [ $? -eq 0 ] || return ${ERR_NODATA}
   cd - &> /dev/null

   #splitted master filename, as for snap split results
   masterSplitted=$( ls "${INPUTDIR}"/target_*_Split_Master.dim ) 
   # check if the file was retrieved, if not exit with the error code $ERR_NODATA
   [ $? -eq 0 ] && [ -e "${masterSplitted}" ] || return ${ERR_NODATA}

   # log the value, it helps debugging. 
   # the log entry is available in the process stderr 
   ciop-log "DEBUG" "The master product to be processed is: ${masterSplitted}"

   #splitted slave filename, as for snap split results
   slaveSplitted=$( ls "${INPUTDIR}"/target_*_Split_Slave.dim )
   # check if the file was retrieved, if not exit with the error code $ERR_NODATA
   [ $? -eq 0 ] && [ -e "${slaveSplitted}" ] || return ${ERR_NODATA}

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The slave product to be processed is: ${slaveSplitted}"
   
   # report activity in the log
   ciop-log "INFO" "Preparing SNAP request file for Orbit file application, Calibration, Back-Geocoding and Enhanced Spectral Diversity"

   # output products filename construction
   masterSplittedBasename=$( basename $masterSplitted )
   swath_pol=$( echo $masterSplittedBasename | sed -n -e 's|target_\(.*\)_Split_Master.dim|\1|p' )
   outputname_Orb_Back_ESD=${TMPDIR}/target_${swath_pol}_Split_Orb_Cal_Back_ESD

   #prepare snap request file for Orbit file application, Calibration, Back-Geocoding and Enhanced Spectral Diversity
   # prepare the SNAP request
   SNAP_REQUEST=$( create_snap_request_orb_cal_back_esd "${masterSplitted}" "${slaveSplitted}" "${orbitType}" "${demType}" "${outputname_Orb_Back_ESD}" )
   [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
   [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
   # report activity in the log
   ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

   # report activity in the log
   ciop-log "INFO" "Invoking SNAP-gpt for Orbit file application, Calibration, Back-Geocoding and Enhanced Spectral Diversity"

   # invoke the ESA SNAP toolbox
   gpt ${SNAP_REQUEST} -c "${CACHE_SIZE}" &> /dev/null
   # check the exit code
   [ $? -eq 0 ] || return $ERR_SNAP

   # report activity in the log
   ciop-log "INFO" "Preparing SNAP request file for Coherence computation and debursting"

   # output products filenames
   outputname_Orb_Back_ESD_DIM=${outputname_Orb_Back_ESD}.dim
   outputnameCoherence=${OUTPUTDIR}/target_${swath_pol}_Split_Orb_Cal_Back_ESD_Coh_Deb
   outputnameCoherenceBasename=$( basename $outputnameCoherence )

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The output product name is: ${outputnameCoherence}"

   #prepare snap request file for coeherence computation
   # prepare the SNAP request
   SNAP_REQUEST=$( create_snap_request_coh_deb "${outputname_Orb_Back_ESD_DIM}" "${cohWinAz}" "${cohWinRg}" "${outputnameCoherence}" )
   [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
   [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
   # report activity in the log
   ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
 
   # report activity in the log
   ciop-log "INFO" "Invoking SNAP-gpt for Coherence computation and debursting"
   
   # invoke the ESA SNAP toolbox
   gpt ${SNAP_REQUEST} -c "${CACHE_SIZE}" &> /dev/null
   # check the exit code
   [ $? -eq 0 ] || return $ERR_SNAP

   # report activity in the log
   ciop-log "INFO" "Preparing SNAP request file for Backscatter debursting"

   # output products filenames
   outputnameSigma=${OUTPUTDIR}/target_${swath_pol}_Split_Orb_Cal_Back_ESD_Deb
   outputnameSigmaBasename=$( basename $outputnameSigma )

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The output product name is: ${outputnameSigma}"

   #prepare snap request file for coeherence computation
   # prepare the SNAP request
   SNAP_REQUEST=$( create_snap_request_deb "${outputname_Orb_Back_ESD_DIM}" "${outputnameSigma}" )
   [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
   [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
   # report activity in the log
   ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

   # report activity in the log
   ciop-log "INFO" "Invoking SNAP-gpt for Backscatter debursting"

   # invoke the ESA SNAP toolbox
   gpt ${SNAP_REQUEST} -c "${CACHE_SIZE}" &> /dev/null
   # check the exit code
   [ $? -eq 0 ] || return $ERR_SNAP

   outputnameZip=${OUTPUTDIR}/target_${swath_pol}_Coh_Cal_Couple
   
   # compress all results 
   cd ${OUTPUTDIR}
   zip -r ${outputnameZip}.zip ${outputnameCoherenceBasename}.d* ${outputnameSigmaBasename}.d* &> /dev/null
   cd - &> /dev/null

   # publish the ESA SNAP result
   ciop-log "INFO" "Publishing generated Coherence and Backscatter Products"
   ciop-publish  ${outputnameZip}.zip       

   # cleanup
   rm -rf ${SNAP_REQUEST} "${INPUTDIR}"/* "${OUTPUTDIR}"/*  
   if [ $DEBUG -ne 1 ] ; then
   	hadoop dfs -rmr "${splittedCouple}"
   fi

}

# create the output folder to store the output products and export it
mkdir -p ${TMPDIR}/output
export OUTPUTDIR=${TMPDIR}/output
mkdir -p ${TMPDIR}/input
export INPUTDIR=${TMPDIR}/input
export DEBUG=0

while read inputfile
do 
    main "${inputfile}"
    res=$?
    [ ${res} -ne 0 ] && exit ${res}
done

exit $SUCCESS

