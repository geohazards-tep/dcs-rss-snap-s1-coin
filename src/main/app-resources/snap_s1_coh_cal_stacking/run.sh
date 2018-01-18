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
ERR_NO_NLOOKS=4
ERR_NLOOKS_NO_INT=5
ERR_NO_PIXEL_SPACING=6
ERR_PIXEL_SPACING_NO_NUM=7
ERR_PROPERTIES_FILE_CREATOR=8
ERR_PCONVERT=9
ERR_COLORBAR_CREATOR=10
ERR_CONVERT=11

# add a trap to exit gracefully
function cleanExit ()
{
    local retval=$?
    local msg=""

    case ${retval} in
        ${SUCCESS})            		msg="Processing successfully concluded";;
        ${ERR_NODATA})         		msg="Could not retrieve the input data";;
        ${SNAP_REQUEST_ERROR})  	msg="Could not create snap request file";;
        ${ERR_SNAP})            	msg="SNAP failed to process";;
        ${ERR_NO_NLOOKS})       	msg="Multilook factor is empty";;
        ${ERR_NLOOKS_NO_INT})   	msg="Multilook factor is not an integer number";;
        ${ERR_NO_PIXEL_SPACING})	msg="Pixel spacing is empty";;
        ${ERR_PIXEL_SPACING_NO_NUM})	msg="Pixel spacing is not a number";;        
        ${ERR_PROPERTIES_FILE_CREATOR})	msg="Could not create the .properties file";;
        ${ERR_PCONVERT})                msg="PCONVERT failed to process";;
        ${ERR_COLORBAR_CREATOR})        msg="Failed during colorbar creation";;
        ${ERR_CONVERT})			msg="Failed during full resolution GeoTIFF creation";;
        *)                      	msg="Unknown error";;
    esac

   [ ${retval} -ne 0 ] && ciop-log "ERROR" "Error ${retval} - ${msg}, processing aborted" || ciop-log "INFO" "${msg}"
   # not allowed in the multi-tenant cluster
   #if [ $DEBUG -ne 1 ] ; then
   #	[ ${retval} -ne 0 ] && hadoop dfs -rmr $(dirname "${inputfiles[0]}")
   #fi
   exit ${retval}
}

trap cleanExit EXIT

function create_snap_request_mrg_ml_spk_tc(){

#function call: SNAP_REQUEST=$( create_snap_request_mrg_ml_spk_tc "${inputDIM[@]}" "${polarisation}" "${nAzLooks}" "${nRgLooks}" "${perform_speckle_filtering}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${output_Mrg_Ml_Tc}" )      

    # function which creates the SNAP request file for the Topsar subswath merging,  
    # multilooking and terrain correction. It returns the path to the request file.
  
    # get number of inputs    
    inputNum=$#
    
    #conversion of first input to array of strings and get all the remaining input
    local -a inputfiles
    local polarisation
    local nAzLooks
    local nRgLooks
    local perform_speckle_filtering
    local demType
    local pixelSpacingInMeter
    local mapProjection
    local output_Mrg_Ml_Tc
 
    # first input file always equal to the first function input
    inputfiles+=("$1")
    
    if [ "$inputNum" -gt "11" ] || [ "$inputNum" -lt "9" ]; then
        return ${SNAP_REQUEST_ERROR}
    elif [ "$inputNum" -eq "9" ]; then
        polarisation=$2
        nAzLooks=$3
	nRgLooks=$4
        perform_speckle_filtering=$5
	demType=$6
	pixelSpacingInMeter=$7
	mapProjection=$8
        output_Mrg_Ml_Tc=$9
    elif [ "$inputNum" -eq "10" ]; then
        inputfiles+=("$2")
        polarisation=$3
        nAzLooks=$4
	nRgLooks=$5
        perform_speckle_filtering=$6
	demType=$7
	pixelSpacingInMeter=$8
	mapProjection=$9
        output_Mrg_Ml_Tc=${10}
    elif [ "$inputNum" -eq "11" ]; then
        inputfiles+=("$2")
        inputfiles+=("$3")
        polarisation=$4
        nAzLooks=$5
	nRgLooks=$6
        perform_speckle_filtering=$7
	demType=$8
	pixelSpacingInMeter=$9
	mapProjection=${10}
        output_Mrg_Ml_Tc=${11}
    fi
    
    local commentRead2Begin=""
    local commentRead2End=""
    local commentRead3Begin=""
    local commentRead3End=""
    local commentMergeBegin=""
    local commentMergeEnd=""
    local commentMergeSource3Begin=""
    local commentMergeSource3End=""
    local commentRead1SourceBegin=""
    local commentRead1SourceEnd=""
    local commentMlBegin=""
    local commentMlEnd=""
    local commentSpkBegin=""
    local commentSpkEnd=""
    
    local beginCommentXML="<!--"
    local endCommentXML="-->"

    # here is the logic to enable the proper snap steps dependent on the number of inputs
    inputFilesNum=${#inputfiles[@]}

    if [ "$inputFilesNum" -gt "3" ] || [ "$inputFilesNum" -lt "1" ]; then
        return ${SNAP_REQUEST_ERROR}
    elif [ "$inputFilesNum" -eq "1" ]; then
    	commentMergeBegin="${beginCommentXML}"
        commentMergeEnd="${endCommentXML}"
        commentRead2Begin="${beginCommentXML}"
        commentRead2End="${endCommentXML}"
        commentRead3Begin="${beginCommentXML}"
        commentRead3End="${endCommentXML}"
    elif [ "$inputFilesNum" -eq "2" ]; then
        commentRead1SourceBegin="${beginCommentXML}"
        commentRead1SourceEnd="${endCommentXML}"
        commentRead3Begin="${beginCommentXML}"
        commentRead3End="${endCommentXML}"
        commentMergeSource3Begin="${beginCommentXML}"
        commentMergeSource3End="${endCommentXML}"
    elif [ "$inputFilesNum" -eq "3" ]; then
        commentRead1SourceBegin="${beginCommentXML}"
        commentRead1SourceEnd="${endCommentXML}"
    fi    
    
    # activation of speckle filtering depending on input flag
    if [[ "${perform_speckle_filtering}" == "true" ]]; then
        commentMlBegin="${beginCommentXML}"
        commentMlEnd="${endCommentXML}"
    else
        commentSpkBegin="${beginCommentXML}"
        commentSpkEnd="${endCommentXML}"
    fi


    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${inputfiles[0]}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
${commentRead2Begin}  <node id="Read(2)">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${inputfiles[1]}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node> ${commentRead2End}
${commentRead3Begin}  <node id="Read(3)">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${inputfiles[2]}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node> ${commentRead3End}
${commentMergeBegin}  <node id="TOPSAR-Merge">
    <operator>TOPSAR-Merge</operator>
    <sources>
      <sourceProduct refid="Read"/>
      <sourceProduct.1 refid="Read(2)"/> 
${commentMergeSource3Begin}      <sourceProduct.2 refid="Read(3)"/> ${commentMergeSource3End}
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations>${polarisation}</selectedPolarisations>
    </parameters>
  </node> ${commentMergeEnd}
  <node id="Multilook">
    <operator>Multilook</operator>
    <sources>
${commentMergeBegin}      <sourceProduct refid="TOPSAR-Merge"/> ${commentMergeEnd}
${commentRead1SourceBegin} <sourceProduct refid="Read"/> ${commentRead1SourceEnd}
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <nRgLooks>${nRgLooks}</nRgLooks>
      <nAzLooks>${nAzLooks}</nAzLooks>
      <outputIntensity>true</outputIntensity>
      <grSquarePixel>true</grSquarePixel>
    </parameters>
  </node>
${commentSpkBegin}  <node id="Speckle-Filter">
    <operator>Speckle-Filter</operator>
    <sources>
      <sourceProduct refid="Multilook"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <filter>Gamma Map</filter>
      <filterSizeX>3</filterSizeX>
      <filterSizeY>3</filterSizeY>
      <dampingFactor>2</dampingFactor>
      <estimateENL>true</estimateENL>
      <enl>1.0</enl>
      <numLooksStr>1</numLooksStr>
      <windowSize>7x7</windowSize>
      <targetWindowSizeStr>3x3</targetWindowSizeStr>
      <sigmaStr>0.9</sigmaStr>
      <anSize>50</anSize>
    </parameters>
  </node>   ${commentSpkEnd}
  <node id="Terrain-Correction">
    <operator>Terrain-Correction</operator>
    <sources>
${commentMlBegin}      <sourceProduct refid="Multilook"/> ${commentMlEnd}
${commentSpkBegin}      <sourceProduct refid="Speckle-Filter"/> ${commentSpkEnd}
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <demName>${demType}</demName>
      <externalDEMFile/>
      <externalDEMNoDataValue>0.0</externalDEMNoDataValue>
      <demResamplingMethod>BILINEAR_INTERPOLATION</demResamplingMethod>
      <imgResamplingMethod>BILINEAR_INTERPOLATION</imgResamplingMethod>
      <pixelSpacingInMeter>${pixelSpacingInMeter}</pixelSpacingInMeter>
      <!-- <pixelSpacingInDegree>1.3474729261792824E-4</pixelSpacingInDegree> -->
      <mapProjection>${mapProjection}</mapProjection>
      <nodataValueAtSea>true</nodataValueAtSea>
      <saveDEM>false</saveDEM>
      <saveLatLon>false</saveLatLon>
      <saveIncidenceAngleFromEllipsoid>false</saveIncidenceAngleFromEllipsoid>
      <saveLocalIncidenceAngle>false</saveLocalIncidenceAngle>
      <saveProjectedLocalIncidenceAngle>false</saveProjectedLocalIncidenceAngle>
      <saveSelectedSourceBand>true</saveSelectedSourceBand>
      <outputComplex>false</outputComplex>
      <applyRadiometricNormalization>false</applyRadiometricNormalization>
      <saveSigmaNought>false</saveSigmaNought>
      <saveGammaNought>false</saveGammaNought>
      <saveBetaNought>false</saveBetaNought>
      <incidenceAngleForSigma0>Use projected local incidence angle from DEM</incidenceAngleForSigma0>
      <incidenceAngleForGamma0>Use projected local incidence angle from DEM</incidenceAngleForGamma0>
      <auxFile>Latest Auxiliary File</auxFile>
      <externalAuxFile/>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="Terrain-Correction"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${output_Mrg_Ml_Tc}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
      <displayPosition x="70.0" y="162.0"/>
    </node>
    <node id="Read(2)">
      <displayPosition x="70.0" y="112.0"/>
    </node>
    <node id="Read(3)">
      <displayPosition x="70.0" y="62.0"/>
    </node>
    <node id="TOPSAR-Merge">
      <displayPosition x="162.0" y="112.0"/>
    </node>
    <node id="Multilook">
      <displayPosition x="291.0" y="112.0"/>
    </node>
    <node id="Terrain-Correction">
      <displayPosition x="472.0" y="112.0"/>
    </node>
    <node id="Write">
      <displayPosition x="810.0" y="131.0"/>
    </node>
  </applicationData>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}
}

function create_snap_request_stack(){
# function call SNAP_REQUEST=$( create_snap_request_stack "${sigma_Mrg_Ml_Tc_DIM}" "${coherence_Mrg_Ml_Tc_DIM}" "${stackProduct}" )

    # function which creates the SNAP request file for the CreateStack operator with 2 input, 
    # and returns the path to the request file.
  
    # get number of inputs    
    inputNum=$#
	# check on number of inputs
    if [ "$inputNum" -ne "3" ]; then
        return ${SNAP_REQUEST_ERROR}
    fi
	
    # get input
    local sigmaDIM=$1
    local coherenceDIM=$2
    local stackProduct=$3
	
    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${coherenceDIM}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="Read(2)">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${sigmaDIM}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="CreateStack">
    <operator>CreateStack</operator>
    <sources>
      <sourceProduct refid="Read"/>
      <sourceProduct.1 refid="Read(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <masterBands/>
      <sourceBands/>
      <resamplingType>NONE</resamplingType>
      <extent>Master</extent>
      <initialOffsetMethod>Product Geolocation</initialOffsetMethod>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="CreateStack"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${stackProduct}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
      <displayPosition x="47.0" y="80.0"/>
    </node>
    <node id="Read(2)">
      <displayPosition x="44.0" y="143.0"/>
    </node>
    <node id="CreateStack">
      <displayPosition x="233.0" y="138.0"/>
    </node>
    <node id="Write">
      <displayPosition x="377.0" y="137.0"/>
    </node>
  </applicationData>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}
}


function create_snap_sigmaAvrgDiff_bandExtract(){
# function call SNAP_REQUEST=$(  create_snap_sigmaAvrgDiff_bandExtract "${stackProduct_DIM}" "${sigmaMasterBand}" "${sigmaSlaveBand}" "${coherenceBand}" "${sigmaDiffName}" "${sigmaAverageName}" "${sigmaMasterName}" "${sigmaSlaveName}" "${coherenceName}" "${rgbCompositeName}" "${sigmaMasterSlaveComposite}" )
   # function which creates the SNAP request file for the computation of backscatter average and difference in dB and to extract the coherence band from the input stack product.
   # It returns the path to the request file.

   # get number of inputs
   inputNum=$#
   # check on number of inputs
   if [ "$inputNum" -lt "9" ] || [ "$inputNum" -gt "11" ]; then
       return ${SNAP_REQUEST_ERROR}
   fi

   # get input
   local stackProduct_DIM=$1
   local sigmaMasterBand=$2
   local sigmaSlaveBand=$3
   local coherenceBand=$4
   local sigmaDiffName=$5
   local sigmaAverageName=$6
   local sigmaMasterName=$7
   local sigmaSlaveName=$8
   local coherenceName=$9
   [ "$inputNum" -eq "10" ] && rgbCompositeName=${10}
   [ "$inputNum" -eq "11" ] && sigmaMasterSlaveComposite=${11}
   
   local commentRgbBegin=""
   local commentRgbEnd=""
   local commentSigmaCompositeBegin=""
   local commentSigmaCompositeEnd=""   

   local beginCommentXML="<!--"
   local endCommentXML="-->"
   # activate/deactivate RGB composite additional output based on number of provided input 
   if [ "$inputNum" -lt "10" ]; then
      commentRgbBegin=${beginCommentXML}
      commentRgbEnd=${endCommentXML}        
   fi 
   # activate/deactivate sigma composite additional output based on number of provided input
   if [ "$inputNum" -lt "11" ]; then
      commentSigmaCompositeBegin=${beginCommentXML}
      commentSigmaCompositeEnd=${endCommentXML}
   fi

   #sets the output filename
   snap_request_filename="${TMPDIR}/$( uuidgen ).xml"
   #write request file 
   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${stackProduct_DIM}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="BandMaths">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="LinearToFromdB"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>sigmaDiff</name>
          <type>float32</type>
          <expression>${sigmaMasterBand}_db - ${sigmaSlaveBand}_db</expression>
          <description/>
          <unit/>
          <noDataValue>0.0</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="BandMaths(2)">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="LinearToFromdB"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>sigmaAverage</name>
          <type>float32</type>
          <expression>(${sigmaMasterBand}_db + ${sigmaSlaveBand}_db) / 2</expression>
          <description/>
          <unit/>
          <noDataValue>0.0</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="LinearToFromdB">
    <operator>LinearToFromdB</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands>${sigmaMasterBand},${sigmaSlaveBand}</sourceBands>
    </parameters>
  </node>
  <node id="Write(2)">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMaths(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${sigmaAverageName}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <node id="Write(3)">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandSelect"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${coherenceName}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <node id="BandSelect">
    <operator>BandSelect</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations/>
      <sourceBands>${coherenceBand}</sourceBands>
      <bandNamePattern/>
    </parameters>
  </node>
  <node id="BandSelect(2)">
    <operator>BandSelect</operator>
    <sources>
      <sourceProduct refid="LinearToFromdB"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations/>
      <sourceBands>${sigmaMasterBand}_db</sourceBands>
      <bandNamePattern/>
    </parameters>
  </node>
  <node id="BandSelect(3)">
    <operator>BandSelect</operator>
    <sources>
      <sourceProduct refid="LinearToFromdB"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations/>
      <sourceBands>${sigmaSlaveBand}_db</sourceBands>
      <bandNamePattern/>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMaths"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${sigmaDiffName}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <node id="Write(4)">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandSelect(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${sigmaMasterName}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <node id="Write(5)">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandSelect(3)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${sigmaSlaveName}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
${commentRgbBegin}  <node id="BandMerge">
    <operator>BandMerge</operator>
    <sources>
      <sourceProduct refid="BandSelect"/>
      <sourceProduct.1 refid="BandMaths(2)"/>
      <sourceProduct.2 refid="BandMaths"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <geographicError>1.0E-5</geographicError>
    </parameters>
  </node>
  <node id="Write(6)">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMerge"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${rgbCompositeName}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node> ${commentRgbEnd}
${commentSigmaCompositeBegin}  <node id="BandMerge(2)">
    <operator>BandMerge</operator>
    <sources>
      <sourceProduct refid="BandSelect(2)"/>
      <sourceProduct.1 refid="BandSelect(3)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <geographicError>1.0E-5</geographicError>
    </parameters>
  </node>
  <node id="Write(7)">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMerge(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${sigmaMasterSlaveComposite}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node> ${commentSigmaCompositeEnd}
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
      <displayPosition x="65.0" y="173.0"/>
    </node>
    <node id="BandMaths">
      <displayPosition x="60.0" y="35.0"/>
    </node>
    <node id="BandMaths(2)">
      <displayPosition x="220.0" y="64.0"/>
    </node>
    <node id="LinearToFromdB">
      <displayPosition x="45.0" y="120.0"/>
    </node>
    <node id="Write(2)">
      <displayPosition x="493.0" y="62.0"/>
    </node>
    <node id="Write(3)">
      <displayPosition x="498.0" y="173.0"/>
    </node>
    <node id="BandSelect">
      <displayPosition x="144.0" y="172.0"/>
    </node>
    <node id="BandSelect(2)">
      <displayPosition x="341.0" y="135.0"/>
    </node>
    <node id="BandSelect(3)">
      <displayPosition x="342.0" y="99.0"/>
    </node>
    <node id="Write(4)">
      <displayPosition x="495.0" y="134.0"/>
    </node>
    <node id="Write(5)">
      <displayPosition x="494.0" y="99.0"/>
    </node>
    <node id="BandMerge">
      <displayPosition x="231.0" y="212.0"/>
    </node>
    <node id="Write(6)">
      <displayPosition x="494.0" y="212.0"/>
    </node>
    <node id="BandMerge(2)">
      <displayPosition x="231.0" y="212.0"/>
    </node>
    <node id="Write(7)">
      <displayPosition x="494.0" y="212.0"/>
    </node>
    <node id="Write">
      <displayPosition x="494.0" y="32.0"/>
    </node>
  </applicationData>
</graph>
EOF

[ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}


}


function propertiesFileCratorPNG_IFG(){
#function call: propertiesFileCratorPNG_IFG "${outputProductTif}" "${outputProductPNG}" "${description}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" "${legendPng}"

    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -lt "9" ] || [ "$inputNum" -gt "10" ]; then
        return ${ERR_PROPERTIES_FILE_CREATOR}
    fi

    # function which creates the .properties file to attach to the output png file
    local outputProductTif=$1
    local outputProductPNG=$2
    local description=$3
    local dateStart=$4
    local dateStop=$5
    local dateDiff_days=$6
    local polarisation=$7
    local snapVersion=$8
    local processingTime=$9
    if [ "$inputNum" -eq "10" ]; then
        legendPng=${10}
	legendPng=http://${HOSTNAME}:50075/streamFile${ciop_wf_run_root}/_results/${legendPng}
    fi 

	
    # extracttion coordinates from gdalinfo
    # from a string like "Upper Left  (  13.0450832,  42.4802388) ( 13d 2'42.30"E, 42d28'48.86"N)" is extracted "13.0450832 42.4802388"
    lon_lat_1=$( gdalinfo "${outputProductTif}" | grep "Lower Left"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
    lon_lat_2=$( gdalinfo "${outputProductTif}" | grep "Upper Left"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
    lon_lat_3=$( gdalinfo "${outputProductTif}" | grep "Upper Right"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
    lon_lat_4=$( gdalinfo "${outputProductTif}" | grep "Lower Right"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
	
    outputProductPNG_basename=$(basename "${outputProductPNG}")
    properties_filename=${outputProductPNG}.properties
    if [ "$inputNum" -eq "9" ]; then	

	cat << EOF > ${properties_filename}
title=${outputProductPNG_basename}
geometry=POLYGON(( ${lon_lat_1}, ${lon_lat_2}, ${lon_lat_3}, ${lon_lat_4}, ${lon_lat_1} ))
description=${description}
dateMaster=${dateStart}
dateSlave=${dateStop}
dateDiff_days=${dateDiff_days}
polarisation=${polarisation}
snapVersion=${snapVersion}
processingTime=${processingTime}
EOF
    else
 	cat << EOF > ${properties_filename}
image_url=${legendPng}
title=${outputProductPNG_basename}
geometry=POLYGON(( ${lon_lat_1}, ${lon_lat_2}, ${lon_lat_3}, ${lon_lat_4}, ${lon_lat_1} ))
description=${description}
dateMaster=${dateStart}
dateSlave=${dateStop}
dateDiff_days=${dateDiff_days}
polarisation=${polarisation}
snapVersion=${snapVersion}
processingTime=${processingTime}
EOF
    fi

    [ $? -eq 0 ] && {
        echo "${properties_filename}"
        return 0
    } || return ${ERR_PROPERTIES_FILE_CREATOR}

}


function propertiesFileCratorPNG_OneBand(){
#function call: propertiesFileCratorPNG_OneBand "${outputProductTif}" "${outputProductPNG}" "${description}" "${date}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" "${legendPng}"

    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -lt "7" ] || [ "$inputNum" -gt "8" ]; then
        return ${ERR_PROPERTIES_FILE_CREATOR}
    fi

    # function which creates the .properties file to attach to the output png file
    local outputProductTif=$1
    local outputProductPNG=$2
    local description=$3
    local date=$4
    local polarisation=$5
    local snapVersion=$6
    local processingTime=$7
    if [ "$inputNum" -eq "8" ]; then
         legendPng=$8
         legendPng=http://${HOSTNAME}:50075/streamFile${ciop_wf_run_root}/_results/${legendPng}
    fi
    
    # extracttion coordinates from gdalinfo
    # from a string like "Upper Left  (  13.0450832,  42.4802388) ( 13d 2'42.30"E, 42d28'48.86"N)" is extracted "13.0450832 42.4802388"
    lon_lat_1=$( gdalinfo "${outputProductTif}" | grep "Lower Left"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
    lon_lat_2=$( gdalinfo "${outputProductTif}" | grep "Upper Left"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
    lon_lat_3=$( gdalinfo "${outputProductTif}" | grep "Upper Right"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
    lon_lat_4=$( gdalinfo "${outputProductTif}" | grep "Lower Right"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )

    outputProductPNG_basename=$(basename "${outputProductPNG}")
    properties_filename=${outputProductPNG}.properties
    if [ "$inputNum" -eq "7" ]; then

        cat << EOF > ${properties_filename}
title=${outputProductPNG_basename}
geometry=POLYGON(( ${lon_lat_1}, ${lon_lat_2}, ${lon_lat_3}, ${lon_lat_4}, ${lon_lat_1} ))
description=${description}
productDate=${date}
polarisation=${polarisation}
snapVersion=${snapVersion}
processingTime=${processingTime}
EOF
    else
        cat << EOF > ${properties_filename}
image_url=${legendPng}
title=${outputProductPNG_basename}
geometry=POLYGON(( ${lon_lat_1}, ${lon_lat_2}, ${lon_lat_3}, ${lon_lat_4}, ${lon_lat_1} ))
description=${description}
productDate=${date}
polarisation=${polarisation}
snapVersion=${snapVersion}
processingTime=${processingTime}
EOF
    fi

    [ $? -eq 0 ] && {
        echo "${properties_filename}"
        return 0
    } || return ${ERR_PROPERTIES_FILE_CREATOR}

}


function propertiesFileCratorTIF_IFG(){
# function call propertiesFileCratorTIF_IFG "${outputProductTif}" "${description}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}"
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "9" ]; then
        return ${ERR_PROPERTIES_FILE_CREATOR}
    fi

    # function which creates the .properties file to attach to the output tif file
    local outputProductTif=$1
    local description=$2
    local dateStart=$3
    local dateStop=$4
    local dateDiff_days=$5 
    local polarisation=$6
    local pixelSpacing=$7
    local snapVersion=$8
    local processingTime=$9

    outputProductTIF_basename=$(basename "${outputProductTif}")
    properties_filename=${outputProductTif}.properties

    cat << EOF > ${properties_filename}
title=${outputProductTIF_basename}
description=${description}
dateMaster=${dateStart}
dateSlave=${dateStop}
dateDiff_days=${dateDiff_days}
polarisation=${polarisation}
pixelSpacing=${pixelSpacing}
snapVersion=${snapVersion}
processingTime=${processingTime}
EOF

    [ $? -eq 0 ] && {
        echo "${properties_filename}"
        return 0
    } || return ${ERR_PROPERTIES_FILE_CREATOR}

}


function propertiesFileCratorTIF_OneBand(){
# function call propertiesFileCratorTIF_OneBand "${outputProductTif}" "${description}" "${date}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}"
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "7" ]; then
        return ${ERR_PROPERTIES_FILE_CREATOR}
    fi

    # function which creates the .properties file to attach to the output tif file
    local outputProductTif=$1
    local description=$2
    local date=$3
    local polarisation=$4
    local pixelSpacing=$5
    local snapVersion=$6
    local processingTime=$7

    outputProductTIF_basename=$(basename "${outputProductTif}")
    properties_filename=${outputProductTif}.properties

    cat << EOF > ${properties_filename}
title=${outputProductTIF_basename}
description=${description}
productDate=${date}
polarisation=${polarisation}
pixelSpacing=${pixelSpacing}
snapVersion=${snapVersion}
processingTime=${processingTime}
EOF

    [ $? -eq 0 ] && {
        echo "${properties_filename}"
        return 0
    } || return ${ERR_PROPERTIES_FILE_CREATOR}

}


function create_snap_request_statsComputation(){
# function call: create_snap_request_statsComputation $tiffProduct $sourceBandName $outputStatsFile
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "3" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi
     
    local tiffProduct=$1
    local sourceBandName=$2
    local outputStatsFile=$3

    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="StatisticsOp">
    <operator>StatisticsOp</operator>
    <sources>
      <sourceProducts></sourceProducts>
    </sources>
    <parameters>
      <sourceProductPaths>${tiffProduct}</sourceProductPaths>
      <shapefile></shapefile>
      <startDate></startDate>
      <endDate></endDate>
      <bandConfigurations>
        <bandConfiguration>
          <sourceBandName>${sourceBandName}</sourceBandName>
          <expression></expression>
          <validPixelExpression></validPixelExpression>
        </bandConfiguration>
      </bandConfigurations>
      <outputShapefile></outputShapefile>
      <outputAsciiFile>${outputStatsFile}</outputAsciiFile>
      <percentiles>90,95</percentiles>
      <accuracy>3</accuracy>
    </parameters>
  </node>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}

}


function colorbarCreator(){
# function call: colorbarCreator $inputColorbar $colorbarDescription $statsFile $outputColorbar

    #function that put value labels to the JET colorbar legend input depending on the
    # provided product statistics   

     # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "4" ] ; then
        return ${ERR_COLORBAR_CREATOR}
    fi
    
    #get input
    local inputColorbar=$1
    local colorbarDescription=$2
    local statsFile=$3
    local outputColorbar=$4

    # get maximum from stats file
    maximum=$(cat "${statsFile}" | grep world | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 5)
    #get minimum from stats file
    minimum=$(cat "${statsFile}" | grep world | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 7)
    #compute colorbar values
    rangeWidth=$(echo "scale=5; $maximum-($minimum)" | bc )
    red=$(echo "scale=5; $minimum" | bc | awk '{printf "%.2f", $0}')
    yellow=$(echo "scale=5; $minimum+$rangeWidth/4" | bc | awk '{printf "%.2f", $0}')
    green=$(echo "scale=5; $minimum+$rangeWidth/2" | bc | awk '{printf "%.2f", $0}')
    cyan=$(echo "scale=5; $minimum+$rangeWidth*3/4" | bc | awk '{printf "%.2f", $0}')    
    blue=$(echo "scale=5; $maximum" | bc | awk '{printf "%.2f", $0}')
    
    # add clolrbar description
    convert -pointsize 15 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 9,22 \"$colorbarDescription\" " $inputColorbar $outputColorbar
    # add color values
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 7,100 \"$red\" " $outputColorbar $outputColorbar
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 76,100 \"$yellow\" " $outputColorbar $outputColorbar
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 147,100 \"$green\" " $outputColorbar $outputColorbar 
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 212,100 \"$cyan\" " $outputColorbar $outputColorbar
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 278,100 \"$blue\" " $outputColorbar $outputColorbar

    return 0

}


function main() {
    #get input product list and convert it into an array
    local -a inputfiles=($@)
    
    #get the number of products to be processed
    inputfilesNum=$#
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Number of input products ${inputfilesNum}"

    # retrieve the parameters value from workflow or job default value
    nAzLooks="`ciop-getparam nAzLooks`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The Azimuth Multilook factor is: ${nAzLooks}"

    #check if not empty and integer
    [ -z "${nAzLooks}" ] && exit ${ERR_NO_NLOOKS}
    re='^[0-9]+$'
    if ! [[ $nAzLooks =~ $re ]] ; then
       exit ${ERR_NLOOKS_NO_INT}
    fi

    # retrieve the parameters value from workflow or job default value
    nRgLooks="`ciop-getparam nRgLooks`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The Range Multilook factor is: ${nRgLooks}"

    #check if not empty and integer
    [ -z "${nRgLooks}" ] && exit ${ERR_NO_NLOOKS}
    re='^[0-9]+$'
    if ! [[ $nRgLooks =~ $re ]] ; then
       exit ${ERR_NLOOKS_NO_INT}
    fi
    
    # retrieve the parameters value from workflow or job default value
    demType="`ciop-getparam demtype`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The DEM type used is: ${demType}"

    # retrieve the parameters value from workflow or job default value
    pixelSpacingInMeter="`ciop-getparam pixelSpacingInMeter`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The pixel spacing in meters is: ${pixelSpacingInMeter}"

    #check if not empty and a real number
    [ -z "${pixelSpacingInMeter}" ] && exit ${ERR_NO_PIXEL_SPACING}

    re='^[0-9]+([.][0-9]+)?$'
    if ! [[ $pixelSpacingInMeter =~ $re ]] ; then
       exit ${ERR_PIXEL_SPACING_NO_NUM}
    fi

    # retrieve the parameters value from workflow or job default value
    mapProjection="`ciop-getparam mapProjection`"
     
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The Map projection used is: ${mapProjection}"

    # loop on input products to retrieve them and fill list for snap req file
    declare -a inputCohDIM
    declare -a inputSigmaDIM
    let "inputfilesNum-=1"    

    for index in `seq 0 $inputfilesNum`;
    do
    	# report activity in log
    	ciop-log "INFO" "Retrieving ${inputfiles[$index]} from storage"

    	retrieved=$( ciop-copy -U -o $INPUTDIR "${inputfiles[$index]}" )
    	# check if the file was retrieved, if not exit with the error code $ERR_NODATA
    	[ $? -eq 0 ] && [ -e "${retrieved}" ] || return ${ERR_NODATA}

    	# report activity in the log
    	ciop-log "INFO" "Retrieved ${retrieved}"

    	cd $INPUTDIR
    	unzip `basename ${retrieved}` &> /dev/null
    	# let's check the return value
    	[ $? -eq 0 ] || return ${ERR_NODATA}
    	cd - &> /dev/null
        
        # current swath and polarization, as for coherence and backscatter couple product name of previous task
        swath_pol=$( echo `basename ${retrieved}` | sed -n -e 's|target_\(.*\)_Coh_Cal_Couple.zip|\1|p' )
	# current subswath Coherence product filename, as for previous task naming convention
    	cohInput=$( ls "${INPUTDIR}"/target_"${swath_pol}"_Split_Orb_Cal_Back_ESD_Coh_Deb.dim )
    	# check if the file was retrieved, if not exit with the error code $ERR_NODATA
	[ $? -eq 0 ] && [ -e "${cohInput}" ] || return ${ERR_NODATA}
    	# log the value, it helps debugging.
    	# the log entry is available in the process stderr
	ciop-log "DEBUG" "Input Coherence product to be processed: ${cohInput}"
		
	# current subswath Backscatter product filename, as for previous task naming convention
    	sigmaInput=$( ls "${INPUTDIR}"/target_"${swath_pol}"_Split_Orb_Cal_Back_ESD_Deb.dim )
    	# check if the file was retrieved, if not exit with the error code $ERR_NODATA
	[ $? -eq 0 ] && [ -e "${sigmaInput}" ] || return ${ERR_NODATA}
    	# log the value, it helps debugging.
    	# the log entry is available in the process stderr
	ciop-log "DEBUG" "Input Backscatter product to be processed: ${sigmaInput}"
		
	# Array append with current Coherence product
    	inputCohDIM+=("${cohInput}")
	# Array append with current Master Backscatter product
    	inputSigmaDIM+=("${sigmaInput}") 

    done

    #get polarisation from input product name, as generated by the core IFG node
    polarisation=$( basename "${inputCohDIM[0]}"  | sed -n -e 's|target_IW._\(.*\)_Split_Orb_Cal_Back_ESD_Coh_Deb.dim|\1|p' )
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Polarisation extracted from input product name: ${polarisation}"

    ### MERGING - MULTILOOKING - TERRAIN CORRECTION PROCESSING
    ## Coherence
    # output products filename
    coherence_Mrg_Ml_Tc=${TMPDIR}/target_IW_${polarisation}_Split_Orb_Cal_Back_ESD_Coh_Deb_Merge_ML_TC
    # coherence mustn't be speckle filtered  
    perform_speckle_filtering="false"
    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file for merging, multilooking and terrain correction processing (Coherence product)"
    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_mrg_ml_spk_tc "${inputCohDIM[@]}" "${polarisation}" "${nAzLooks}" "${nRgLooks}" "${perform_speckle_filtering}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${coherence_Mrg_Ml_Tc}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"     
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for merging, multilooking and terrain correction processing (Coherence product)"
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    if [ ${QL_BRANCH} -eq 1 ]; then
        ## Coherence Quick-Look
        # Get size from coherence product
        # coherence product name
        coherenceName_IMG=$( ls ${coherence_Mrg_Ml_Tc}.data/coh*.img )
    	ncols=$( gdalinfo ${coherenceName_IMG} | grep "Size is" | sed -n -e 's|Size is \(.*\),.*|\1|p' )
    	nrows=$( gdalinfo ${coherenceName_IMG} | grep "Size is" | sed -n -e 's|Size is.*, \(.*\)|\1|p'  )
    	ciop-log "DEBUG" "Number of columns of output product: ${ncols}"
    	ciop-log "DEBUG" "Number of rows of output product: ${nrows}"
    	# get ml factors for output quick-look generation
    	targetNcols=2048
    	rg_ml_factor_rel=$(echo "scale=0; $ncols/$targetNcols" | bc )
    	ciop-log "DEBUG" "Range multilook factor relative to output product: ${rg_ml_factor_rel}"
    	rg_ml_factor_ql=$(echo "scale=0; $rg_ml_factor_rel*$nRgLooks" | bc )
    	az_ml_factor_ql=$(echo "scale=0; $rg_ml_factor_rel*$nAzLooks" | bc )
    	pixelSpacingInMeter_ql=$(echo "scale=0; $rg_ml_factor_rel*$pixelSpacingInMeter" | bc )
    	ciop-log "DEBUG" "Range multilook factor for QL: ${rg_ml_factor_ql}"
    	ciop-log "DEBUG" "Azimuth multilook factor for QL: ${az_ml_factor_ql}"
    	ciop-log "DEBUG" "Pixel spacing in meters QL: ${pixelSpacingInMeter_ql}"
    	# report activity in the log
    	ciop-log "INFO" "Preparing SNAP request file for merging, multilooking and terrain correction processing (Coherence Quick-Look product)"
    	coherence_Mrg_Ml_Tc_QL=${TMPDIR}/target_IW_${polarisation}_Split_Orb_Cal_Back_ESD_Coh_Deb_Merge_ML_TC_QL
    	# prepare the SNAP request
    	SNAP_REQUEST=$( create_snap_request_mrg_ml_spk_tc "${inputCohDIM[@]}" "${polarisation}" "${az_ml_factor_ql}" "${rg_ml_factor_ql}" "${perform_speckle_filtering}" "${demType}" "${pixelSpacingInMeter_ql}" "${mapProjection}" "${coherence_Mrg_Ml_Tc_QL}" )
    	[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    	[ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    	# report activity in the log
    	ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    	# report activity in the log
    	ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for merging, multilooking and terrain correction processing (Coherence Quick-Look product)"
    	# invoke the ESA SNAP toolbox
    	gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    	# check the exit code
    	[ $? -eq 0 ] || return $ERR_SNAP
    fi
    ## Backscatter
    # output products filename
    sigma_Mrg_Ml_Tc=${TMPDIR}/target_IW_${polarisation}_Split_Orb_Cal_Back_ESD_Deb_Merge_ML_TC
    # intensity is speckle filtered
    perform_speckle_filtering="true"
    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file for merging, multilooking, speckle filtering and terrain correction processing (Backscatter product)"
    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_mrg_ml_spk_tc "${inputSigmaDIM[@]}" "${polarisation}" "${nAzLooks}" "${nRgLooks}" "${perform_speckle_filtering}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${sigma_Mrg_Ml_Tc}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for merging, multilooking, speckle filtering and terrain correction processing (Backscatter product)"
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    if [ ${QL_BRANCH} -eq 1 ]; then
        ## Backscatter Quick-Look
    	# report activity in the log
    	ciop-log "INFO" "Preparing SNAP request file for merging, multilooking, speckle filtering and terrain correction processing (Backscatter Quick-Look product)"
    	# output products filename
    	sigma_Mrg_Ml_Tc_QL=${TMPDIR}/target_IW_${polarisation}_Split_Orb_Cal_Back_ESD_Deb_Merge_ML_TC_QL
    	# speckle filtering can be avoided with the very high multilook factor used for the quick-look generation
    	perform_speckle_filtering="false"
    	# prepare the SNAP request
    	SNAP_REQUEST=$( create_snap_request_mrg_ml_spk_tc "${inputSigmaDIM[@]}" "${polarisation}" "${az_ml_factor_ql}" "${rg_ml_factor_ql}" "${perform_speckle_filtering}" "${demType}" "${pixelSpacingInMeter_ql}" "${mapProjection}" "${sigma_Mrg_Ml_Tc_QL}" )
    	[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    	[ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    	# report activity in the log
    	ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    	# report activity in the log
    	ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for merging, multilooking, speckle filtering and terrain correction processing (Backscatter Quick-Look product)"
    	# invoke the ESA SNAP toolbox
    	gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    	# check the exit code
    	[ $? -eq 0 ] || return $ERR_SNAP
    fi
    # cleanup input products for the merging, multilooking and terrain correction processing
    rm -rf "${INPUTDIR}"/*	
    
    ### PRODUCTS STACKING
    # input products filename
    sigma_Mrg_Ml_Tc_DIM=${sigma_Mrg_Ml_Tc}.dim
    coherence_Mrg_Ml_Tc_DIM=${coherence_Mrg_Ml_Tc}.dim	
    # output product filename
    stackProduct=${TMPDIR}/target_IW_${polarisation}_Coh_Sigma_Stack
    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file to create stack with Master Backscatter, Slave Backscatter and Coherence products"
    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_stack "${sigma_Mrg_Ml_Tc_DIM}" "${coherence_Mrg_Ml_Tc_DIM}" "${stackProduct}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file to create stack with Master Backscatter, Slave Backscatter and Coherence products"
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    if [ ${QL_BRANCH} -eq 1 ]; then
        ## Stacking for QL product
    	sigma_Mrg_Ml_Tc_QL_DIM=${sigma_Mrg_Ml_Tc_QL}.dim
    	coherence_Mrg_Ml_Tc_QL_DIM=${coherence_Mrg_Ml_Tc_QL}.dim
    	# output product filename
    	stackProduct_QL=${TMPDIR}/target_IW_${polarisation}_Coh_Sigma_Stack_QL
    	# report activity in the log
    	ciop-log "INFO" "Preparing SNAP request file to create stack with Master Backscatter, Slave Backscatter and Coherence products (Quick-Look product)"
    	# prepare the SNAP request
    	SNAP_REQUEST=$( create_snap_request_stack "${sigma_Mrg_Ml_Tc_QL_DIM}" "${coherence_Mrg_Ml_Tc_QL_DIM}" "${stackProduct_QL}" )
    	[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    	[ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    	# report activity in the log
    	ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    	# report activity in the log
    	ciop-log "INFO" "Invoking SNAP-gpt on the generated request file to create stack with Master Backscatter, Slave Backscatter and Coherence products (Quick-Look product)"
    	# invoke the ESA SNAP toolbox
    	gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    	# check the exit code
    	[ $? -eq 0 ] || return $ERR_SNAP
    fi
    ### AUX: get master/slave backscatter and coherence source bands from the stack product
    # The source band names are useful for the following processing
    local sigmaMasterBand
    local sigmaSlaveBand
    local coherenceBand
    # get master backscatter band name
    sigmaMasterBand=$( ls "${stackProduct}".data/Intensity_"${polarisation}"_mst_*.img )
    # check if the file was retrieved, if not exit with the error code $ERR_NODATA
    [ $? -eq 0 ] && [ -e "${sigmaMasterBand}" ] || return ${ERR_NODATA}
    sigmaMasterBand=$( basename "${sigmaMasterBand}" | sed -n -e 's|^\(.*\).img|\1|p' )
    #get date from band name
    dateMaster=$(echo ${sigmaMasterBand} | sed -n -e 's|^.*mst_\(.*\)_slv.*|\1|p')
    # get slave backscatter band name
    sigmaSlaveBand=$( ls "${stackProduct}".data/Intensity_"${polarisation}"_slv*.img )
    # check if the file was retrieved, if not exit with the error code $ERR_NODATA
    [ $? -eq 0 ] && [ -e "${sigmaSlaveBand}" ] || return ${ERR_NODATA}
    sigmaSlaveBand=$( basename "${sigmaSlaveBand}" | sed -n -e 's|^\(.*\).img|\1|p' )
    #get date from band name
    dateSlave=$(echo ${sigmaSlaveBand} | sed -n -e 's|^.*slv1_\(.*\)_slv2.*|\1|p')
    # get coherence band name
    coherenceBand=$( ls "${stackProduct}".data/coh_*.img )
    # check if the file was retrieved, if not exit with the error code $ERR_NODATA
    [ $? -eq 0 ] && [ -e "${coherenceBand}" ] || return ${ERR_NODATA}
    coherenceBand=$( basename "${coherenceBand}" | sed -n -e 's|^\(.*\).img|\1|p' )

    ### COMPUTE SIGMA AVERAGE AND DIFFERENCE IN DB AND EXTRACT COHERENCE FROM STACK PRODUCT
    stackProduct_DIM=${stackProduct}.dim
    sigmaDiffBasename=sigmaDiff_dB_IW_${polarisation}_${dateMaster}_${dateSlave}
    sigmaDiffName=${OUTPUTDIR}/${sigmaDiffBasename}
    sigmaAverageBasename=sigmaAverage_dB_IW_${polarisation}_${dateMaster}_${dateSlave}
    sigmaAverageName=${OUTPUTDIR}/${sigmaAverageBasename}
    sigmaMasterBasename=sigmaMaster_dB_IW_${polarisation}_${dateMaster}
    sigmaMasterName=${OUTPUTDIR}/${sigmaMasterBasename}
    sigmaSlaveBasename=sigmaSlave_dB_IW_${polarisation}_${dateSlave}
    sigmaSlaveName=${OUTPUTDIR}/${sigmaSlaveBasename}
    coherenceBasename=coherence_IW_${polarisation}_${dateMaster}_${dateSlave}
    coherenceName=${OUTPUTDIR}/${coherenceBasename}
    rgbCompositeBasename=combined_coh_sigmaAvrg_sigmaDiff_IW_${polarisation}_${dateMaster}_${dateSlave}
    rgbCompositeName=${OUTPUTDIR}/${rgbCompositeBasename}
    sigmaMasterSlaveCompositeBasename=combined_sigmaMaster_dB_sigmaSlave_dB_IW_${polarisation}_${dateMaster}_${dateSlave}
    sigmaMasterSlaveComposite=${OUTPUTDIR}/${sigmaMasterSlaveCompositeBasename}
    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file to Backscatter average and difference computation (in dB) and individual bands extraction from stack product"
    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_sigmaAvrgDiff_bandExtract "${stackProduct_DIM}" "${sigmaMasterBand}" "${sigmaSlaveBand}" "${coherenceBand}" "${sigmaDiffName}" "${sigmaAverageName}" "${sigmaMasterName}" "${sigmaSlaveName}" "${coherenceName}" "${rgbCompositeName}" "${sigmaMasterSlaveComposite}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file to Backscatter average and difference computation (in dB) and individual bands extraction from stack product"
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    if [ ${QL_BRANCH} -eq 1 ]; then
        ## perform dB computations and individual bands extraction for Quick-Look product
    	stackProduct_QL_DIM=${stackProduct_QL}.dim
    	sigmaDiffBasename_QL=sigmaDiff_dB_IW_${polarisation}_${dateMaster}_${dateSlave}_QL
    	sigmaDiffName_QL=${TMPDIR}/${sigmaDiffBasename_QL}
    	sigmaAverageBasename_QL=sigmaAverage_dB_IW_${polarisation}_${dateMaster}_${dateSlave}_QL
    	sigmaAverageName_QL=${TMPDIR}/${sigmaAverageBasename_QL}
    	sigmaMasterBasename_QL=sigmaMaster_dB_IW_${polarisation}_${dateMaster}_QL
    	sigmaMasterName_QL=${TMPDIR}/${sigmaMasterBasename_QL}
    	sigmaSlaveBasename_QL=sigmaSlave_dB_IW_${polarisation}_${dateSlave}_QL
    	sigmaSlaveName_QL=${TMPDIR}/${sigmaSlaveBasename_QL}
    	coherenceBasename_QL=coherence_IW_${polarisation}_${dateMaster}_${dateSlave}_QL
    	coherenceName_QL=${TMPDIR}/${coherenceBasename_QL}
    	# report activity in the log
    	ciop-log "INFO" "Preparing SNAP request file to Backscatter average and difference computation (in dB) and individual bands extraction from stack product (Quick-Look product)"
    	# prepare the SNAP request
    	SNAP_REQUEST=$( create_snap_sigmaAvrgDiff_bandExtract "${stackProduct_QL_DIM}" "${sigmaMasterBand}" "${sigmaSlaveBand}" "${coherenceBand}" "${sigmaDiffName_QL}" "${sigmaAverageName_QL}" "${sigmaMasterName_QL}" "${sigmaSlaveName_QL}" "${coherenceName_QL}")
    	[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    	[ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    	# report activity in the log
    	ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    	# report activity in the log
    	ciop-log "INFO" "Invoking SNAP-gpt on the generated request file to Backscatter average and difference computation (in dB) and individual bands extraction from stack product (Quick-Look product)"
    	# invoke the ESA SNAP toolbox
    	gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    	# check the exit code
    	[ $? -eq 0 ] || return $ERR_SNAP
    else
        stackProduct_QL_DIM=${stackProduct_DIM}
        sigmaDiffBasename_QL=${sigmaDiffBasename}
        sigmaDiffName_QL=${sigmaDiffName}
        sigmaAverageBasename_QL=${sigmaAverageBasename}
        sigmaAverageName_QL=${sigmaAverageName}
        sigmaMasterBasename_QL=${sigmaMasterBasename}
        sigmaMasterName_QL=${sigmaMasterName}
        sigmaSlaveBasename_QL=${sigmaSlaveBasename}
        sigmaSlaveName_QL=${sigmaSlaveName}
        coherenceBasename_QL=${coherenceBasename}
        coherenceName_QL=${coherenceName}
    fi
    # sigma master product
    sigmaMasterName_TIF=${sigmaMasterName}.tif
    # sigma slave product
    sigmaSlaveName_TIF=${sigmaSlaveName}.tif
    # coherence product
    coherenceName_TIF=${coherenceName}.tif
    # sigma average product
    sigmaAverageName_TIF=${sigmaAverageName}.tif
    # sigma difference product
    sigmaDiffName_TIF=${sigmaDiffName}.tif

    ### QUICK LOOK PRODUCTS GENERATION
    # report activity in the log
    ciop-log "INFO" "Creating quick-look for each output product"
    ## Create RGB composite R=coherence G=sigmaAverage B=sigmaDiff
    rgbCompositeNameTIF=${rgbCompositeName}.tif
    # Full Resolution product 8 bit encoded (supported by GEP V2 for a potential full resolution visualization)
    rgbCompositeNameFullResTIF=${rgbCompositeName}_FullRes.tif
    pconvert -b 1,2,3 -f tif -o ${TMPDIR} ${rgbCompositeNameTIF} &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # output of pconvert
    pconvertOutRgbCompositeTIF=${TMPDIR}/${rgbCompositeBasename}.tif
    gdal_translate -ot Byte -of GTiff -b 1 -b 2 -b 3 -scale -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" ${pconvertOutRgbCompositeTIF} ${TMPDIR}/temp-outputfile.tif
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    gdalwarp -ot Byte -t_srs EPSG:3857 -srcnodata 0 -dstnodata 0 -dstalpha -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" ${TMPDIR}/temp-outputfile.tif ${rgbCompositeNameFullResTIF}
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    #Add overviews
    gdaladdo -r average ${rgbCompositeNameFullResTIF} 2 4 8 16
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    rm ${TMPDIR}/temp-outputfile.tif
    # RGB Quick-look
    # Fix of not overlapping master and slave visualization issue by producing an image with the minimum extent (i.e. the coherence).
    # pconvert already fix this issue by using footprint of first band (coherence) 
    combinedRGB=combined_coh_sigmaAvrg_sigmaDiff_IW_${polarisation}_${dateMaster}_${dateSlave}_QL
    # pconvert to have a tiff with 2048 pixel width (it also produces all bands with 0 outside image borders), overwrite of previous full resolution tif pconvertOutRgbCompositeTIF 
    pconvert -b 1,2,3 -W 2048 -f tif -o ${TMPDIR} ${pconvertOutRgbCompositeTIF} &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # alpha band is corrupted by pconvert resampling --> use gdal_translate to remove alpha band
    gdal_translate -ot Byte -of PNG -b 1 -b 2 -b 3 -scale ${pconvertOutRgbCompositeTIF} ${TMPDIR}/temp-outputfile.png
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    # convert to remove black (zero) background
    convert ${TMPDIR}/temp-outputfile.png -alpha set -channel RGBA -fill none -opaque black ${OUTPUTDIR}/${combinedRGB}.png &> /dev/null
    rm ${TMPDIR}/temp-outputfile.png
    ## Create RGB composite R=sigma master G=sigma slave B=sigma slave
    sigmaMasterSlaveCompositeTIF=${sigmaMasterSlaveComposite}.tif
    # Full Resolution product 8 bit encoded (supported by GEP V2 for a potential full resolution visualization)
    sigmaMasterSlaveCompositeFullResTIF=${sigmaMasterSlaveComposite}_FullRes.tif
    pconvert -b 1,2,2 -f tif -o ${TMPDIR} ${sigmaMasterSlaveCompositeTIF} &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # output of pconvert
    pconvertOutTIF=${TMPDIR}/${sigmaMasterSlaveCompositeBasename}.tif
    gdal_translate -ot Byte -of GTiff -b 1 -b 2 -b 3 -scale -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" ${pconvertOutTIF} ${TMPDIR}/temp-outputfile.tif
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    gdalwarp -ot Byte -t_srs EPSG:3857 -srcnodata 0 -dstnodata 0 -dstalpha -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" ${TMPDIR}/temp-outputfile.tif ${sigmaMasterSlaveCompositeFullResTIF}
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    #Add overviews
    gdaladdo -r average ${sigmaMasterSlaveCompositeFullResTIF} 2 4 8 16
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    rm ${TMPDIR}/temp-outputfile.tif
    # RGB Quick-look
    # Fix of not overlapping master and slave visualization issue by producing an image with the minimum extent (i.e. the coherence).
    # pconvert already fix this issue by using footprint of first band (coherence)
    sigmaMasterSlaveCompositeRGB=${sigmaMasterSlaveCompositeBasename}_QL
    # pconvert to have a tiff with 2048 pixel width (it also produces all bands with 0 outside image borders), overwrite of previous full resolution tif pconvertOutTIF
    pconvert -b 1,2,3 -W 2048 -f tif -o ${TMPDIR} ${pconvertOutTIF} &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # alpha band is corrupted by pconvert resampling --> use gdal_translate to remove alpha band
    gdal_translate -ot Byte -of PNG -b 1 -b 2 -b 3 -scale ${pconvertOutTIF} ${TMPDIR}/temp-outputfile.png
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    # convert to remove black (zero) background
    convert ${TMPDIR}/temp-outputfile.png -alpha set -channel RGBA -fill none -opaque black ${OUTPUTDIR}/${sigmaMasterSlaveCompositeRGB}.png &> /dev/null
    rm ${TMPDIR}/temp-outputfile.png
    ## sigma master product
    sigmaMasterName_QL_TIF=${sigmaMasterName_QL}.tif
    pconvert -f png -b 1 -W 2048 -o "${OUTPUTDIR}" "${sigmaMasterName_QL_TIF}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # statistics extraction
    # Build source band name for statistics computation
    sourceBand=${sigmaMasterBand}_db
    # Build statistics file name
    statsFile=${TMPDIR}/temp.stats
    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_statsComputation "${sigmaMasterName_TIF}" "${sourceBand}" "${statsFile}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for statistics extraction from Master backscatter dB product"
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    #Colorbar legend to be customized with product statistics
    colorbarInput=$_CIOP_APPLICATION_PATH/gpt/colorbar_gray.png #sample Gray Colorbar (as used by pconvert with single band products) colorbar image
    #Output name of customized colorbar legend
    sigmaMasterColorbarOutput=${sigmaMasterName}_legend.png
    sigmaMasterColorbarBasename=$(basename "${sigmaMasterColorbarOutput}")
    # colorbar description
    colorbarDescription="Sigma_0 Master [dB]"
    #Customize colorbar with product statistics
    retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" "${statsFile}" "${sigmaMasterColorbarOutput}" )
    rm ${statsFile}
    ## sigma slave product
    sigmaSlaveName_QL_TIF=${sigmaSlaveName_QL}.tif
    pconvert -f png -b 1 -W 2048 -o "${OUTPUTDIR}" "${sigmaSlaveName_QL_TIF}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # statistics extraction
    # Build source band name for statistics computation
    sourceBand=${sigmaSlaveBand}_db
    # Build statistics file name
    statsFile=${TMPDIR}/temp.stats
    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_statsComputation "${sigmaSlaveName_TIF}" "${sourceBand}" "${statsFile}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for statistics extraction from Slave backscatter product"
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    #Output name of customized colorbar legend
    sigmaSlaveColorbarOutput=${sigmaSlaveName}_legend.png
    sigmaSlaveColorbarBasename=$(basename "${sigmaSlaveColorbarOutput}")
    # colorbar description
    colorbarDescription="Sigma_0 Slave [dB]"
    #Customize colorbar with product statistics
    retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" "${statsFile}" "${sigmaSlaveColorbarOutput}" )
    rm ${statsFile}
    ## coherence product
    coherenceName_QL_TIF=${coherenceName_QL}.tif
    pconvert -f png -b 1 -W 2048 -o "${OUTPUTDIR}" "${coherenceName_QL_TIF}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # statistics extraction
    # Build source band name for statistics computation
    sourceBand=${coherenceBand}
    # Build statistics file name
    statsFile=${TMPDIR}/temp.stats
    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_statsComputation "${coherenceName_TIF}" "${sourceBand}" "${statsFile}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for statistics extraction from Coherence product"
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    #Output name of customized colorbar legend
    coherenceColorbarOutput=${coherenceName}_legend.png
    coherenceColorbarBasename=$(basename "${coherenceColorbarOutput}")
    # colorbar description
    colorbarDescription="Coherence"
    #Customize colorbar with product statistics
    retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" "${statsFile}" "${coherenceColorbarOutput}" )
    rm ${statsFile}
    ## sigma average product
    sigmaAverageName_QL_TIF=${sigmaAverageName_QL}.tif
    # alpha band is corrupted by pconvert resampling --> use gdal_translate to remove alpha band
    gdal_translate -ot Byte -of PNG -b 2 -scale ${pconvertOutRgbCompositeTIF} ${TMPDIR}/temp-outputfile.png
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    # convert to remove black (zero) background
    convert ${TMPDIR}/temp-outputfile.png -alpha set -channel RGBA -fill none -opaque black ${OUTPUTDIR}/${sigmaAverageBasename_QL}.png &> /dev/null
    rm ${TMPDIR}/temp-outputfile.png
    # statistics extraction
    # Build source band name for statistics computation
    sourceBand="sigmaAverage"
    # Build statistics file name
    statsFile=${TMPDIR}/temp.stats
    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_statsComputation "${sigmaAverageName_TIF}" "${sourceBand}" "${statsFile}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for statistics extraction from Sigma Average product"
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    #Output name of customized colorbar legend
    sigmaAverageColorbarOutput=${sigmaAverageName}_legend.png
    sigmaAverageColorbarBasename=$(basename "${sigmaAverageColorbarOutput}")
    # colorbar description
    colorbarDescription="Sigma_0 Average [dB]"
    #Customize colorbar with product statistics
    retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" "${statsFile}" "${sigmaAverageColorbarOutput}" )
    rm ${statsFile}
    ## sigma difference product
    sigmaDiffName_QL_TIF=${sigmaDiffName_QL}.tif
    # alpha band is corrupted by pconvert resampling --> use gdal_translate to remove alpha band
    gdal_translate -ot Byte -of PNG -b 3 -scale ${pconvertOutRgbCompositeTIF} ${TMPDIR}/temp-outputfile.png
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    # convert to remove black (zero) background
    convert ${TMPDIR}/temp-outputfile.png -alpha set -channel RGBA -fill none -opaque black ${OUTPUTDIR}/${sigmaDiffBasename_QL}.png &> /dev/null
    # statistics extraction
    # Build source band name for statistics computation
    sourceBand="sigmaDiff"
    # Build statistics file name
    statsFile=${TMPDIR}/temp.stats
    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_statsComputation "${sigmaDiffName_TIF}" "${sourceBand}" "${statsFile}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for statistics extraction from Sigma Diff product"
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    #Output name of customized colorbar legend
    sigmaDiffColorbarOutput=${sigmaDiffName}_legend.png
    sigmaDiffColorbarBasename=$(basename "${sigmaDiffColorbarOutput}")
    # colorbar description
    colorbarDescription="Sigma_0 Difference [dB]"
    #Customize colorbar with product statistics
    retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" "${statsFile}" "${sigmaDiffColorbarOutput}" )
    rm ${statsFile} 
    rm ${TMPDIR}/temp-outputfile.png
    rm ${pconvertOutRgbCompositeTIF} ${pconvertOutTIF}

    # get timing info for the tif properties file
    dateStart_s=$(date -d "${dateMaster}" +%s)
    dateStop_s=$(date -d "${dateSlave}" +%s)
    dateDiff_s=$(echo "scale=0; $dateStop_s-$dateStart_s" | bc )
    secondsPerDay="86400"
    dateDiff_days=$(echo "scale=0; $dateDiff_s/$secondsPerDay" | bc )
    pixelSpacing=${pixelSpacingInMeter}m
    processingTime=$( date )

    # report activity in the log
    ciop-log "INFO" "Creating properties files"
    #create .properties file for composite RGB png quick-look
    description="Quick Look product for Coherence and Intensity RGB combination. Red=Coherence, Green=Intensity average in dB, Blue=Intensity difference in dB"
    outCombinedRGB_properties=$( propertiesFileCratorPNG_IFG "${coherenceName_QL_TIF}" "${OUTPUTDIR}/${combinedRGB}.png" "${description}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Composite Coh, Sigma Avg, Sigma Diff RGB properties file created: ${outCombinedRGB_properties}"
    #create .properties file for composite sigma master sigam slave RGB png quick-look
    description="Quick Look product of Sigma Master, Sigma Slave, Sigma Slave RGB combination. Red=Sigma Master in dB, Green=Sigma Slave in dB, Blue=Sigma Slave in dB"
    outSigmaMasterSlaveCompositeRGB_properties=$( propertiesFileCratorPNG_IFG "${sigmaMasterName_QL_TIF}" "${OUTPUTDIR}/${sigmaMasterSlaveCompositeRGB}.png" "${description}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Composite Sigma Master, Sigma Slave, Sigma Slave RGB properties file created: ${outSigmaMasterSlaveCompositeRGB_properties}"
    #create .properties file for sigma master png quick-look
    description="Quick Look product of Intensity in dB of the Master product"
    outSigmaMaster_properties=$( propertiesFileCratorPNG_OneBand "${sigmaMasterName_QL_TIF}" "${OUTPUTDIR}/${sigmaMasterBasename_QL}.png" "${description}" "${dateMaster}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" "${sigmaMasterColorbarBasename}" )
    # report activity in the log
    ciop-log "DEBUG" "Sigma Master properties file created: ${outSigmaMaster_properties}"
    #create .properties file for sigma slave png quick-look
    description="Quick Look product of Intensity in dB of the Slave product"
    outSigmaSlave_properties=$( propertiesFileCratorPNG_OneBand "${sigmaSlaveName_QL_TIF}" "${OUTPUTDIR}/${sigmaSlaveBasename_QL}.png" "${description}" "${dateSlave}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" "${sigmaSlaveColorbarBasename}" )
    # report activity in the log
    ciop-log "DEBUG" "Sigma Slave properties file created: ${outSigmaSlave_properties}"
    #create .properties file for coherence png quick-look
    description="Quick Look product of Coherence product computed on the input SLC couple"
    outCoh_properties=$( propertiesFileCratorPNG_IFG "${coherenceName_QL_TIF}" "${OUTPUTDIR}/${coherenceBasename_QL}.png" "${description}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" "${coherenceColorbarBasename}" )
    # report activity in the log
    ciop-log "DEBUG" "Coherence properties file created: ${outCoh_properties}"
    #create .properties file for sigma average png quick-look
    description="Quick Look product of Intensity average in dB computed on the input SLC couple"
    outSigmaAverage_properties=$( propertiesFileCratorPNG_IFG "${sigmaAverageName_QL_TIF}" "${OUTPUTDIR}/${sigmaAverageBasename_QL}.png" "${description}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" "${sigmaAverageColorbarBasename}" )
    # report activity in the log
    ciop-log "DEBUG" "Sigma average properties file created: ${outSigmaAverage_properties}"
    #create .properties file for sigma difference png quick-look
    description="Quick Look product of Intensity difference in dB computed on the input SLC couple"
    outSigmaDiff_properties=$( propertiesFileCratorPNG_IFG "${sigmaDiffName_QL_TIF}" "${OUTPUTDIR}/${sigmaDiffBasename_QL}.png" "${description}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" "${sigmaDiffColorbarBasename}" )
    # report activity in the log
    ciop-log "DEBUG" "Sigma difference properties file created: ${outSigmaDiff_properties}"

    # create properties file for coherence tif product
    descriptionCoh="Coherence product computed on the input SLC couple"
    outputCohTIF_properties=$( propertiesFileCratorTIF_IFG "${coherenceName_TIF}" "${descriptionCoh}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Coherence properties file created: ${outputCohTIF_properties}"

    # create properties file for Intensity average tif product
    descriptionSigmaAverage="Intensity average in dB computed on the input SLC couple"
    outputSigmaAverageTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaAverageName_TIF}" "${descriptionSigmaAverage}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Backscatter average properties file created: ${outputSigmaAverageTIF_properties}"

    # create properties file for Intensity difference average tif product
    descriptionSigmaDiff="Intensity difference in dB computed on the input SLC couple"
    outputSigmaDiffTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaDiffName_TIF}" "${descriptionSigmaDiff}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Backscatter difference properties file created: ${outputSigmaDiffTIF_properties}"

    # create properties file for Intensity Master tif product
    descriptionSigmaMaster="Intensity in dB of the Master product"
    outputSigmaMasterTIF_properties=$( propertiesFileCratorTIF_OneBand "${sigmaMasterName_TIF}" "${descriptionSigmaMaster}" "${dateMaster}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Master Backscatter properties file created: ${outputSigmaMasterTIF_properties}"

    # create properties file for Intensity Slave tif product
    descriptionSigmaSlave="Intensity in dB of the Slave product"
    outputSigmaSlaveTIF_properties=$( propertiesFileCratorTIF_OneBand "${sigmaSlaveName_TIF}" "${descriptionSigmaSlave}" "${dateSlave}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Slave Backscatter properties file created: ${outputSigmaSlaveTIF_properties}"

    # create properties file for RGB composite tif product
    descriptionRgbComposite="Coherence and Intensity RGB combination. Red=Coherence, Green=Intensity average in dB, Blue=Intensity difference in dB"
    outputRgbCompositeNameTIF_properties=$( propertiesFileCratorTIF_IFG "${rgbCompositeNameTIF}" "${descriptionRgbComposite}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Combined RGB product properties file created: ${outputRgbCompositeNameTIF_properties}"    

    # create properties file for RGB composite tif product
    descriptionRgbComposite="Sigma Master and Sigma Slave stack (Sigma_0 in dB)"
    outputRgbCompositeNameTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaMasterSlaveCompositeTIF}" "${descriptionRgbComposite}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Combined RGB product properties file created: ${outputRgbCompositeNameTIF_properties}"

    # publish the ESA SNAP results
    ciop-log "INFO" "Publishing Output Products" 
    ciopPublishOut=$( ciop-publish -m "${OUTPUTDIR}"/* )
    # cleanup temp dir and output dir 
    rm -rf  "${TMPDIR}"/* "${OUTPUTDIR}"/* 
    # cleanup output products generated by the previous task
   # not allowed in the multi-tenant cluster
    #if [ $DEBUG -ne 1 ] ; then
   # 	for index in `seq 0 $inputfilesNum`;
   # 	do
   # 		hadoop dfs -rmr "${inputfiles[$index]}"     	
    #	done
    #fi 

    return ${SUCCESS}
}

# create the output folder to store the output products and export it
mkdir -p ${TMPDIR}/output
export OUTPUTDIR=${TMPDIR}/output
mkdir -p ${TMPDIR}/input
export INPUTDIR=${TMPDIR}/input
export DEBUG=0
export QL_BRANCH=0

declare -a inputfiles

while read inputfile; do
    inputfiles+=("${inputfile}") # Array append
done

main ${inputfiles[@]}
res=$?
[ ${res} -ne 0 ] && exit ${res}

exit $SUCCESS
