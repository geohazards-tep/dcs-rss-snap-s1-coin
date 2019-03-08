#!/bin/bash

# source the ciop functions (e.g. ciop-log, ciop-getparam)
source ${ciop_job_include}

# set the environment variables to use ESA SNAP toolbox
source $_CIOP_APPLICATION_PATH/gpt/snap_include.sh

## put /opt/anaconda/bin ahead to the PATH list to ensure gdal to point to the anaconda installation dir
export PATH=/opt/anaconda/bin:${PATH}



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
      <nodataValueAtSea>false</nodataValueAtSea>
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
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>sigmaDiff</name>
          <type>float32</type>
          <expression>if (!nan(${coherenceBand})) then (10*log10(${sigmaMasterBand}) - 10*log10(${sigmaSlaveBand})) else NaN</expression>
          <description/>
          <unit/>
          <noDataValue>NaN</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="BandMaths(2)">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>sigmaAverage</name>
          <type>float32</type>
          <expression>if (!nan(${coherenceBand})) then ((10*log10(${sigmaMasterBand}) + 10*log10(${sigmaSlaveBand})) / 2) else NaN</expression>
          <description/>
          <unit/>
          <noDataValue>NaN</noDataValue>
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
Title=${outputProductTIF_basename}
Service\ Name=COIN
Description=${description}
Master\ Date=${dateStart}
Slave\ Date=${dateStop}
Time\ Separation\ \(days\)=${dateDiff_days}
Polarisation=${polarisation}
Pixel\ Spacing=${pixelSpacing}
Snap\ Version=${snapVersion}
Processing\ Time=${processingTime}
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
Title=${outputProductTIF_basename}
Service\ Name=COIN
Description=${description}
Product\ Date=${date}
Polarisation=${polarisation}
Pixel\ Spacing=${pixelSpacing}
Snap\ Version=${snapVersion}
Processing\ Time=${processingTime}
EOF

    [ $? -eq 0 ] && {
        echo "${properties_filename}"
        return 0
    } || return ${ERR_PROPERTIES_FILE_CREATOR}

}


function create_snap_request_statsComputation(){
# function call: create_snap_request_statsComputation $tiffProduct $sourceBandName $outputStatsFile $pc_csv_list
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -lt "3" ] || [ "$inputNum" -gt "4" ]; then
        return ${SNAP_REQUEST_ERROR}
    fi

    local tiffProduct=$1
    local sourceBandName=$2
    local outputStatsFile=$3
    local pc_csv_list=""
    [ "$inputNum" -eq "3" ] && pc_csv_list="90,95" || pc_csv_list=$4
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
      <percentiles>${pc_csv_list}</percentiles>
      <accuracy>4</accuracy>
    </parameters>
  </node>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}

}


# function that put value labels (assumed to be 5 vlaues between min and max included) 
# to the colorbar legend input depending on the provided min and max values
function colorbarCreator(){
# function call: colorbarCreator $inputColorbar $colorbarDescription $minimum $maximum $outputColorbar

# get number of inputs
inputNum=$#
# check on number of inputs
if [ "$inputNum" -ne "5" ] ; then
    return ${ERR_COLORBAR_CREATOR}
fi
    
#get input
local inputColorbar=$1
local colorbarDescription=$2
local minimum=$3
local maximum=$4
local outputColorbar=$5

#compute colorbar values
rangeWidth=$(echo "scale=5; $maximum-($minimum)" | bc )
val_1=$(echo "scale=5; $minimum" | bc | awk '{printf "%.2f", $0}')
val_2=$(echo "scale=5; $minimum+$rangeWidth/4" | bc | awk '{printf "%.2f", $0}')
val_3=$(echo "scale=5; $minimum+$rangeWidth/2" | bc | awk '{printf "%.2f", $0}')
val_4=$(echo "scale=5; $minimum+$rangeWidth*3/4" | bc | awk '{printf "%.2f", $0}')    
val_5=$(echo "scale=5; $maximum" | bc | awk '{printf "%.2f", $0}')
    
# add clolrbar description
convert -pointsize 15 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 9,22 \"$colorbarDescription\" " $inputColorbar $outputColorbar
# add color values
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 7,100 \"$val_1\" " $outputColorbar $outputColorbar
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 76,100 \"$val_2\" " $outputColorbar $outputColorbar
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 147,100 \"$val_3\" " $outputColorbar $outputColorbar 
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 212,100 \"$val_4\" " $outputColorbar $outputColorbar
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 278,100 \"$val_5\" " $outputColorbar $outputColorbar

return 0

}


# function that put value labels (assumed to be 2 values for each axis) for the RGB colortable
# to the colorbar legend input depending on the provided min and max values
function colorbarCreatorRGB(){
# function call colorbarCreatorRGB "${colorbarInput}" "${colorbarDescription}" "${minRED}" "${maxRED}" "${minGREEN}" "${maxGREEN}" "${minBLUE}" "${maxBLUE}" "${rgbCompositeColorbarOutput}" 
# get number of inputs
inputNum=$#
# check on number of inputs
if [ "$inputNum" -ne "9" ] ; then
    return ${ERR_COLORBAR_CREATOR}
fi

#get input
local inputColorbar=$1
local colorbarDescription=$2
local minRED=$3
local maxRED=$4
local minGREEN=$5
local maxGREEN=$6
local minBLUE=$7
local maxBLUE=$8
local outputColorbar=$9

# cut values to the second decimal digit
minRED=$(echo "scale=5; $minRED" | bc | awk '{printf "%.1f", $0}')
maxRED=$(echo "scale=5; $maxRED" | bc | awk '{printf "%.1f", $0}')
minGREEN=$(echo "scale=5; $minGREEN" | bc | awk '{printf "%.1f", $0}')
maxGREEN=$(echo "scale=5; $maxGREEN" | bc | awk '{printf "%.1f", $0}')
minBLUE=$(echo "scale=5; $minBLUE" | bc | awk '{printf "%.1f", $0}')
maxBLUE=$(echo "scale=5; $maxBLUE" | bc | awk '{printf "%.1f", $0}')

# add colorbar description
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 25,395 \"$colorbarDescription\" " $inputColorbar $outputColorbar
# add color values
# min red
convert -pointsize 11 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 115,215 \"$minRED\" " $outputColorbar $outputColorbar
# max red
convert -pointsize 11 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 30,310 \"$maxRED\" " $outputColorbar $outputColorbar
# min green
convert -pointsize 11 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 155,235 \"$minGREEN\" " $outputColorbar $outputColorbar
# max green
convert -pointsize 11 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 270,265 \"$maxGREEN\" " $outputColorbar $outputColorbar
# min blue
convert -pointsize 11 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 165,190 \"$minBLUE\" " $outputColorbar $outputColorbar
# max blue
convert -pointsize 11 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 160,50 \"$maxBLUE\" " $outputColorbar $outputColorbar

return 0
}


# function that creates a full resolution tif product that can be correctly shown on GEP
function visualization_product_creator_one_band(){
# function call visualization_product_creator_one_band ${inputTif} ${sourceBandName} ${min_val} ${max_val} ${outputTif}
inputTif=$1
sourceBandName=$2
min_val=$3
max_val=$4
outputTif=$5
# check if min_val and max_val are absolute values or percentiles
# pc values are assumed like pc<value> with <value> it's an integer between 0 and 100
pc_test=$(echo "${min_val}" | grep "pc")
[ "${pc_test}" = "" ] && pc_test="false"
# extract coefficient for linear stretching (min and max out are related to a tiff with 8bit uint precision, 0 is kept for alpha band)
min_out=1
max_out=255
if [ "${pc_test}" = "false" ]; then
# min_val and max_val are absolute values
    $_CIOP_APPLICATION_PATH/snap_s1_coh_cal_stacking/linearEquationCoefficients.py ${min_val} ${max_val} ${min_out} ${max_out} > ab.txt
else
# min_val and max_val are percentiles
    #min max percentiles to be used in histogram stretching
    pc_min=$( echo $min_val | sed -n -e 's|^.*pc\(.*\)|\1|p')
    pc_max=$( echo $max_val | sed -n -e 's|^.*pc\(.*\)|\1|p')
    pc_min_max=$( extract_pc1_pc2 $inputTif $sourceBandName $pc_min $pc_max )
    [ $? -eq 0 ] || return ${ERR_CONVERT}
    $_CIOP_APPLICATION_PATH/snap_s1_coh_cal_stacking/linearEquationCoefficients.py ${pc_min_max} ${min_out} ${max_out} > ab.txt
fi 
a=$( cat ab.txt | grep a | sed -n -e 's|^.*a=\(.*\)|\1|p')
b=$( cat ab.txt | grep b |  sed -n -e 's|^.*b=\(.*\)|\1|p')

ciop-log "INFO" "Linear stretching for image: $inputTif"
SNAP_REQUEST=$( create_snap_request_linear_stretching "${inputTif}" "${sourceBandName}" "${a}" "${b}" "${min_out}" "${max_out}" "temp-outputfile.tif" )
[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
# invoke the ESA SNAP toolbox
gpt ${SNAP_REQUEST} -c "${CACHE_SIZE}" &> /dev/null
# check the exit code
[ $? -eq 0 ] || return $ERR_SNAP

ciop-log "INFO" "Reprojecting and alpha band addition to image: $inputTif"
gdalwarp -ot Byte -srcnodata 0 -dstnodata 0 -dstalpha -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "ALPHA=YES" -t_srs EPSG:3857 temp-outputfile.tif ${outputTif} &> /dev/null
returnCode=$?

[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
rm -f temp-outputfile*
#add overlay
gdaladdo -r average ${outputTif} 2 4 8 16 &> /dev/null
returnCode=$?
[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
# echo of input min max values (usefule mainly when pc_test=true but provided in both cases)
if [ "${pc_test}" = "false" ]; then
    echo ${min_val} ${max_val}
else
    echo ${pc_min_max}
fi

return 0
}


#function that extracts a couple of percentiles from an input TIFF for the selected source band contained in it
function extract_pc1_pc2(){
# function call: extract_pc1_pc2 $tiffProduct $sourceBandName $pc1 $pc2

# get number of inputs
inputNum=$#
# check on number of inputs
if [ "$inputNum" -ne "4" ] ; then
    return ${SNAP_REQUEST_ERROR}
fi

local tiffProduct=$1
local sourceBandName=$2
local pc1=$3
local pc2=$4
local pc_csv_list=${pc1},${pc2}
# report activity in the log
ciop-log "INFO" "Extracting percentiles ${pc1} and ${pc2} from ${sourceBandName} contained in ${tiffProduct}"
# Build statistics file name
statsFile=${TMPDIR}/temp.stats
# prepare the SNAP request
SNAP_REQUEST=$( create_snap_request_statsComputation "${tiffProduct}" "${sourceBandName}" "${statsFile}" "${pc_csv_list}" )
[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
# report activity in the log
ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
# report activity in the log
ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for statistics extraction"
# invoke the ESA SNAP toolbox
gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
# check the exit code
[ $? -eq 0 ] || return $ERR_SNAP

# get maximum from stats file
percentile_1=$(cat "${statsFile}" | grep world | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 8)
#get minimum from stats file
percentile_2=$(cat "${statsFile}" | grep world | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 9)

rm ${statsFile}
echo ${percentile_1} ${percentile_2}
return 0

}


function create_snap_request_linear_stretching(){
# function call: create_snap_request_linear_stretching "${inputfileTIF}" "${sourceBandName}" "${linearCoeff}" "${offset}" "${min_out}" "${max_out}" "${outputfileTIF}"

# function which creates the actual request from
# a template and returns the path to the request

# get number of inputs
inputNum=$#
# check on number of inputs
if [ "$inputNum" -ne "7" ] ; then
    return ${SNAP_REQUEST_ERROR}
fi

local inputfileTIF=$1
local sourceBandName=$2
local linearCoeff=$3
local offset=$4
local min_out=$5
local max_out=$6
local outputfileTIF=$7

#sets the output filename
snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${inputfileTIF}</file>
    </parameters>
  </node>
  <node id="BandMaths">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>quantized</name>
          <type>uint8</type>
          <expression>if fneq(${sourceBandName},0) then max(min(floor(${sourceBandName}*${linearCoeff}+${offset}),${max_out}),${min_out}) else 0</expression>
          <description/>
          <unit/>
          <noDataValue>0</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMaths"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputfileTIF}</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
            <displayPosition x="37.0" y="134.0"/>
    </node>
    <node id="BandMaths">
      <displayPosition x="472.0" y="131.0"/>
    </node>
    <node id="Write">
            <displayPosition x="578.0" y="133.0"/>
    </node>
  </applicationData>
</graph>
EOF
[ $? -eq 0 ] && {
    echo "${snap_request_filename}"
    return 0
    } || return ${SNAP_REQUEST_ERROR}

}

function create_snap_visualization_bands_coh_sigma(){
#function call create_snap_visualization_bands_coh_sigma 

# Get number of input
inputNum=$#
# check on number of inputs
if [ "$inputNum" -ne "5" ] ; then
    return ${SNAP_REQUEST_ERROR}
fi

local rgbcomposite=$1
local green_output=$2
local blue_output=$3
local coherence_band=$4
local red_output=$5
#sets the output filename
snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${rgbcomposite}</file>
    </parameters>
  </node>
  <node id="Write(2)">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMaths(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${green_output}</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <node id="Write(3)">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMaths(3)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${blue_output}</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <node id="BandMaths">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>Red</name>
          <type>uint8</type>
          <expression>if fneq(${coherence_band},0) then max(min(floor(${coherence_band}*256.565656566-1.56565656566),255),1) else 0</expression>
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
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>Green</name>
          <type>uint8</type>
          <expression>if fneq(${coherence_band},0) then max(min(floor(sigmaAverage*12.7+191.5),255),1) else 0</expression>
          <description/>
          <unit/>
          <noDataValue>0.0</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="BandMaths(3)">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>Blue</name>
          <type>uint8</type>
          <expression>sigmaAverage==0</expression>
          <description/>
          <unit/>
          <noDataValue>0.0</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMaths"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${red_output}</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
            <displayPosition x="37.0" y="134.0"/>
    </node>
    <node id="Write(2)">
      <displayPosition x="452.0" y="138.0"/>
    </node>
    <node id="Write(3)">
      <displayPosition x="458.0" y="224.0"/>
    </node>
    <node id="BandMaths">
      <displayPosition x="223.0" y="51.0"/>
    </node>
    <node id="BandMaths(2)">
      <displayPosition x="215.0" y="128.0"/>
    </node>
    <node id="BandMaths(3)">
      <displayPosition x="244.0" y="233.0"/>
    </node>
    <node id="Write">
            <displayPosition x="460.0" y="60.0"/>
    </node>
  </applicationData>
</graph>
EOF
[ $? -eq 0 ] && {
    echo "${snap_request_filename}"
    return 0
    } || return ${SNAP_REQUEST_ERROR}

}

function create_snap_sigmaMasterSlave_clip(){
#function call create_snap_sigmaMasterSlave_clip  "${sigmaMasterSlaveCompositeTIF}" "${sigmaMasterBand}_db" "${sigmaSlaveBand}_db" "${min_val}" "${max_val}" "${sigmaMasterSlaveCompositeClip_TIF}" 
## Function that starting from sigmaMasterSlave stack product, 
## clips the backscatter db values between a min and max values 

# Get number of input
inputNum=$#
# check on number of inputs
if [ "$inputNum" -ne "6" ] ; then
    return ${SNAP_REQUEST_ERROR}
fi

local sigmaMasterSlaveCompositeTIF=$1
local sigmaMasterBand=$2
local sigmaSlaveBand=$3
local min_val=$4
local max_val=$5
local sigmaMasterSlaveCompositeClip_TIF=$6

#sets the output filename
snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>$sigmaMasterSlaveCompositeTIF</file>
    </parameters>
  </node>
  <node id="BandMaths(1)">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>$sigmaMasterBand</name>
          <type>float32</type>
          <expression>if (!nan($sigmaMasterBand) &amp;&amp; !nan($sigmaSlaveBand)) then (if $sigmaMasterBand&lt;=$min_val then $min_val else (if $sigmaMasterBand&gt;=$max_val then $max_val  else $sigmaMasterBand)) else NaN</expression>
          <description/>
          <unit/>
          <noDataValue>NaN</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="BandMaths(2)">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>$sigmaSlaveBand</name>
          <type>float32</type>
          <expression>if (!nan($sigmaMasterBand) &amp;&amp; !nan($sigmaSlaveBand)) then (if $sigmaSlaveBand&lt;=$min_val then $min_val else (if $sigmaSlaveBand&gt;=$max_val then $max_val  else $sigmaSlaveBand)) else NaN</expression>
          <description/>
          <unit/>
          <noDataValue>NaN</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="BandMerge">
    <operator>BandMerge</operator>
    <sources>
      <sourceProduct refid="BandMaths(1)"/>
      <sourceProduct.1 refid="BandMaths(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <geographicError>1.0E-5</geographicError>
    </parameters>
  </node>
  <node id="BandMaths(3)">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="BandMerge"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>$sigmaMasterBand</name>
          <type>float32</type>
          <expression>if ($sigmaMasterBand!=0 &amp;&amp; $sigmaSlaveBand!=0) then $sigmaMasterBand  else NaN</expression>
          <description/>
          <unit/>
          <noDataValue>NaN</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="BandMaths(4)">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="BandMerge"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>$sigmaSlaveBand</name>
          <type>float32</type>
          <expression>if ($sigmaMasterBand!=0 &amp;&amp; $sigmaSlaveBand!=0) then $sigmaSlaveBand  else NaN</expression>
          <description/>
          <unit/>
          <noDataValue>NaN</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="BandMerge(2)">
    <operator>BandMerge</operator>
    <sources>
      <sourceProduct refid="BandMaths(3)"/>
      <sourceProduct.1 refid="BandMaths(4)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <geographicError>1.0E-5</geographicError>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMerge(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>$sigmaMasterSlaveCompositeClip_TIF</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
            <displayPosition x="37.0" y="134.0"/>
    </node>
    <node id="BandMaths">
      <displayPosition x="472.0" y="131.0"/>
    </node>
    <node id="Write">
            <displayPosition x="578.0" y="133.0"/>
    </node>
  </applicationData>
</graph>
EOF
[ $? -eq 0 ] && {
    echo "${snap_request_filename}"
    return 0
    } || return ${SNAP_REQUEST_ERROR}
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
    ## Backscatter
    # output products filename
    sigma_Mrg_Ml_Tc=${TMPDIR}/target_IW_${polarisation}_Split_Orb_Cal_Back_ESD_Deb_Merge_ML_TC
    # intensity no more speckle filtered according to updated requirements
    perform_speckle_filtering="false"
    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file for merging, multilooking, speckle filtering and terrain correction processing (Backscatter product)"
    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_mrg_ml_spk_tc "${inputSigmaDIM[@]}" "${polarisation}" "${nAzLooks}" "${nRgLooks}" "${perform_speckle_filtering}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${sigma_Mrg_Ml_Tc}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for merging, multilooking and terrain correction processing (Backscatter product)"
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
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
    rgbCompositeBasename=coh_sigmaAvrg_IW_${polarisation}_${dateMaster}_${dateSlave}_Coh_Ampl
    rgbCompositeName=${OUTPUTDIR}/${rgbCompositeBasename}
    sigmaMasterSlaveCompositeBasename=sigmaSlave_dB_${dateSlave}_sigmaMaster_dB_${dateMaster}_IW_${polarisation}_Ampl_Change
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
    if (( "${pixelSpacingInMeter}" >= "30" )); then
		### FULL RESOLUTION PRODUCTS GENERATION
		# report activity in the log
		ciop-log "INFO" "Pixel spacing is: {pixelSpacingInMeter}, its >= 30 meter, therefore chosen for pconvert method of creating visualization products."

		ciop-log "INFO" "Creating full resolution visualization products"
		## Create RGB composite R=coherence G=sigmaAverage B=null
		rgbCompositeNameTIF=${rgbCompositeName}.tif
		# edit on the fly the RGB image profile file that will be applied by pconvert
		cat << EOF > ${TMPDIR}/coh_sigmaAvg_null.rgb
#RGB-Image Profile
#Fri Mar 23 16:46:55 CET 2018
blue=0
name=coh_sigmaAvg_null
green=if fneq(${coherenceBand},0) then max(min(floor(sigmaAverage*12.7+191.5),255),1) else 0
red=if fneq(${coherenceBand},0) then max(min(floor(${coherenceBand}*256.565656566-1.56565656566),255),1) else 0
EOF
		# Full Resolution product 8 bit encoded 
		rgbCompositeNameFullResTIF=${rgbCompositeName}.rgb.tif
		pconvert -f tif -p ${TMPDIR}/coh_sigmaAvg_null.rgb -s 0,0 -o ${TMPDIR} ${rgbCompositeNameTIF} &> /dev/null
		# check the exit code
		[ $? -eq 0 ] || return $ERR_PCONVERT
		# output of pconvert
		pconvertOutRgbCompositeTIF=${TMPDIR}/${rgbCompositeBasename}.tif
		# remove corrupted alpha band through gdal_translate
		gdal_translate -ot Byte -of GTiff -b 1 -b 2 -b 3 -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" ${pconvertOutRgbCompositeTIF} temp-outputfile.tif
		returnCode=$?
		[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
		# reprojection
		gdalwarp -ot Byte -t_srs EPSG:3857 -srcnodata 0 -dstnodata 0 -dstalpha -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" temp-outputfile.tif ${rgbCompositeNameFullResTIF}
		returnCode=$?
		[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
		# Add overviews
		gdaladdo -r average ${rgbCompositeNameFullResTIF} 2 4 8 16
		returnCode=$?
		[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
		rm ${pconvertOutRgbCompositeTIF} temp-outputfile.tif
		# PNG output
		rgbCompositeNameFullResPNG=${rgbCompositeName}.png
		pconvert -f png -p ${TMPDIR}/coh_sigmaAvg_null.rgb -s 0,0 -o ${TMPDIR} ${rgbCompositeNameTIF} &> /dev/null
		# check the exit code
		[ $? -eq 0 ] || return $ERR_PCONVERT
		# output of pconvert
		pconvertOutRgbCompositePNG=${TMPDIR}/${rgbCompositeBasename}.png
		# remove black background
		convert ${pconvertOutRgbCompositePNG} -alpha set -channel RGBA -fill none -opaque black ${rgbCompositeNameFullResPNG}
		rm ${pconvertOutRgbCompositePNG}
		# remove physical product
		rm ${rgbCompositeNameTIF}
		# visualization product is the unique generated output for the RGB combination
		mv ${rgbCompositeNameFullResTIF} ${rgbCompositeNameTIF}
		# Colorbar legend to be published 
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/coh_sigmaAvg_null_colormap.png
		# Output name of customized colorbar legend
		rgbCompositeColorbarOutput=${rgbCompositeName}.tif.legend.png
		cp ${colorbarInput} ${rgbCompositeColorbarOutput}
		## Full resolution image creation for Sigma Master product
		# Visualization product name
		sigmaMasterNameFullResTIF=${sigmaMasterName}.rgb.tif
		# Source band name 
		sourceBand=${sigmaMasterBand}_db
		# define min max values in dB for sigma visualization
		min_val=-15
		max_val=5
		# call function for visualization product generator 
		min_max_val=$( visualization_product_creator_one_band "${sigmaMasterName_TIF}" "${sourceBand}" "${min_val}" "${max_val}" "${sigmaMasterNameFullResTIF}" )
		retCode=$?
		[ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
		[ $retCode -eq 0 ] || return $retCode
		# Colorbar legend to be customized with product statistics
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/colorbar_gray.png #sample Gray Colorbar (as used by pconvert with single band products) colorbar image
		# Output name of customized colorbar legend
		sigmaMasterColorbarOutput=${sigmaMasterName}.tif.legend.png
		# colorbar description
		colorbarDescription="Sigma_0 Master [dB]"
		#Customize colorbar with product statistics
		retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${sigmaMasterColorbarOutput}" )
		## Full resolution image creation for Sigma Slave product
		# Visualization product name
		sigmaSlaveNameFullResTIF=${sigmaSlaveName}.rgb.tif
		# Source band name
		sourceBand=${sigmaSlaveBand}_db
		# call function for visualization product generator
		min_max_val=$( visualization_product_creator_one_band "${sigmaSlaveName_TIF}" "${sourceBand}" "${min_val}" "${max_val}" "${sigmaSlaveNameFullResTIF}" )
		retCode=$?
		[ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
		[ $retCode -eq 0 ] || return $retCode
		# Output name of customized colorbar legend
		sigmaSlaveColorbarOutput=${sigmaSlaveName}.tif.legend.png
		# colorbar description
		colorbarDescription="Sigma_0 Slave [dB]"
		# Customize colorbar with product statistics
		retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${sigmaSlaveColorbarOutput}" )
		## Full resolution image creation for Coeherence product
		# Visualization product name
		coherenceNameFullResTIF=${coherenceName}.rgb.tif
		# Build source band name for statistics computation
		sourceBand=${coherenceBand}
		# define percentiles min max values for coherence visualization
		min_val="pc2"
		max_val="pc96"
		# call function for visualization product generator
		min_max_val=$( visualization_product_creator_one_band "${coherenceName_TIF}" "${sourceBand}" "${min_val}" "${max_val}" "${coherenceNameFullResTIF}" )
		retCode=$?
		[ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
		[ $retCode -eq 0 ] || return $retCode
		# Colorbar legend to be customized with product statistics
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/colorbar_gray.png #sample Gray Colorbar (as used by pconvert with single band products) colorbar image
		# Output name of customized colorbar legend
		coherenceColorbarOutput=${coherenceName}.tif.legend.png
		# colorbar description
		colorbarDescription="Coherence"
		# Customize colorbar with product statistics
		retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${coherenceColorbarOutput}" )
		## Full resolution image creation for Sigma Average product
		# Visualization product name
		sigmaAverageNameFullResTIF=${sigmaAverageName}.rgb.tif
		# Build source band name for statistics computation
		sourceBand="sigmaAverage"
		# define min max values for sigma average visualization
		min_val=-15
		max_val=5
		# call function for visualization product generator
		min_max_val=$( visualization_product_creator_one_band "${sigmaAverageName_TIF}" "${sourceBand}" "${min_val}" "${max_val}" "${sigmaAverageNameFullResTIF}" )
		retCode=$?
		[ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
		[ $retCode -eq 0 ] || return $retCode
		# Colorbar legend to be customized with product statistics
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/colorbar_gray.png #sample Gray Colorbar (as used by pconvert with single band products) colorbar image
		# Output name of customized colorbar legend
		sigmaAverageColorbarOutput=${sigmaAverageName}.tif.legend.png
		# colorbar description
		colorbarDescription="Sigma_0 Average [dB]"
		#Customize colorbar with product statistics
		retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${sigmaAverageColorbarOutput}" )
		## Full resolution image creation for Sigma Difference product
		# Visualization product name
		sigmaDiffNameFullResTIF=${sigmaDiffName}.rgb.tif
		# Build source band name for statistics computation
		sourceBand="sigmaDiff"
		# define min max percebtiles values for sigma average visualization
		min_val="pc2"
		max_val="pc96"
		# call function for visualization product generator
		min_max_val=$( visualization_product_creator_one_band "${sigmaDiffName_TIF}" "${sourceBand}" "${min_val}" "${max_val}" "${sigmaDiffNameFullResTIF}" )
		retCode=$?
		[ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
		[ $retCode -eq 0 ] || return $retCode
		# Colorbar legend to be customized with product statistics
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/colorbar_gray.png #sample Gray Colorbar (as used by pconvert with single band products) colorbar image
		# Output name of customized colorbar legend
		sigmaDiffColorbarOutput=${sigmaDiffName}.tif.legend.png
		# colorbar description
		colorbarDescription="Sigma_0 Difference [dB]"
		# Customize colorbar with product statistics
		retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${sigmaDiffColorbarOutput}" )
		## Create RGB composite R=sigma master G=sigma slave B=sigma slave
		sigmaMasterSlaveCompositeTIF=${sigmaMasterSlaveComposite}.tif
		sigmaMasterSlaveCompositeClip_TIF=${sigmaMasterSlaveComposite}_clip.tif
		# Clip values between -15 and +5 dB 
		# report activity in the log
		ciop-log "INFO" "Preparing SNAP request file to clip Backscatter master and slave values"
		min_val=-15
		max_val=5
		# prepare the SNAP request
		SNAP_REQUEST=$( create_snap_sigmaMasterSlave_clip "${sigmaMasterSlaveCompositeTIF}" "${sigmaMasterBand}_db" "${sigmaSlaveBand}_db" "${min_val}" "${max_val}" "${sigmaMasterSlaveCompositeClip_TIF}" )
		[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
		[ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
		# report activity in the log
		ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
		# report activity in the log
		ciop-log "INFO" "Invoking SNAP-gpt on the generated request file clip Backscatter master and slave values"
		# invoke the ESA SNAP toolbox
		gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
		# check the exit code
		[ $? -eq 0 ] || return $ERR_SNAP
		# Full Resolution product 8 bit encoded
		# The output for the RGB combination is a couple of visualization products
		# - A GeoTiff to be displayed on the map
		# - A PNG file  
		rm ${sigmaMasterSlaveCompositeTIF}
		sigmaMasterSlaveCompositeFullResTIF=${sigmaMasterSlaveCompositeTIF}
		pconvert -b 2,1,1 -s 0,0 -f tif -o ${TMPDIR} ${sigmaMasterSlaveCompositeClip_TIF} &> /dev/null
		# PNG creation
		pconvert -b 2,1,1 -s 0,0 -f png -o ${TMPDIR} ${sigmaMasterSlaveCompositeClip_TIF} &> /dev/null
		# check the exit code
		[ $? -eq 0 ] || return $ERR_PCONVERT
		# output of pconvert
		pconvertOutTIF=${TMPDIR}/${sigmaMasterSlaveCompositeBasename}_clip.tif
		# output of pconvert
		pconvertOutPNG=${TMPDIR}/${sigmaMasterSlaveCompositeBasename}_clip.png 
		sigmaMasterSlaveCompositeFullResPNG=${sigmaMasterSlaveComposite}.png
		mv ${pconvertOutPNG} ${sigmaMasterSlaveCompositeFullResPNG}
		# reprojection
		gdalwarp -ot Byte -t_srs EPSG:3857 -srcalpha -dstalpha -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" ${pconvertOutTIF} ${sigmaMasterSlaveCompositeFullResTIF}
		#Add overviews
		gdaladdo -r average ${sigmaMasterSlaveCompositeFullResTIF} 2 4 8 16
		returnCode=$?
		[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
		rm ${pconvertOutTIF} ${sigmaMasterSlaveCompositeClip_TIF}
		# Colorbar legend to be customized with product statistics
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/rgb_cube_sigmaS_sigmaM_sigmaM.png # RGB cube
		# Output name of customized colorbar legend
		sigmaMasterSlaveCompositeColorbarOutput=${sigmaMasterSlaveComposite}.tif.legend.png
		# colorbar description
		colorbarDescription="Amplitude Change RGB Composite"
		#Customize colorbar with product statistics
		retVal=$(colorbarCreatorRGB "${colorbarInput}" "${colorbarDescription}" "${min_val}" "${max_val}" "${min_val}" "${max_val}" "${min_val}" "${max_val}" "${sigmaMasterSlaveCompositeColorbarOutput}" )

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
		# create properties file for coherence tif product
		descriptionCoh="Coherence computed on input SLC couple"
		outputCohTIF_properties=$( propertiesFileCratorTIF_IFG "${coherenceName}" "${descriptionCoh}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Coherence properties file created: ${outputCohTIF_properties}"
		# create properties file for Intensity average tif product
		descriptionSigmaAverage="Intensity average in dB of input SLC couple"
		outputSigmaAverageTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaAverageName}" "${descriptionSigmaAverage}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Backscatter average properties file created: ${outputSigmaAverageTIF_properties}"
		# create properties file for Intensity difference average tif product
		descriptionSigmaDiff="Intensity difference in dB of input SLC couple"
		outputSigmaDiffTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaDiffName}" "${descriptionSigmaDiff}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Backscatter difference properties file created: ${outputSigmaDiffTIF_properties}"
		# create properties file for Intensity Master tif product
		descriptionSigmaMaster="Intensity in dB of the Master product"
		outputSigmaMasterTIF_properties=$( propertiesFileCratorTIF_OneBand "${sigmaMasterName}" "${descriptionSigmaMaster}" "${dateMaster}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Master Backscatter properties file created: ${outputSigmaMasterTIF_properties}"
		# create properties file for Intensity Slave tif product
		descriptionSigmaSlave="Intensity in dB of the Slave product"
		outputSigmaSlaveTIF_properties=$( propertiesFileCratorTIF_OneBand "${sigmaSlaveName}" "${descriptionSigmaSlave}" "${dateSlave}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Slave Backscatter properties file created: ${outputSigmaSlaveTIF_properties}"
		# create properties file for RGB composite tif product
		descriptionRgbComposite="Coherence and Intensity RGB composite"
		outputRgbCompositeNameTIF_properties=$( propertiesFileCratorTIF_IFG "${rgbCompositeName}" "${descriptionRgbComposite}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Combined RGB product properties file created: ${outputRgbCompositeNameTIF_properties}"    
		# create properties file for RGB composite tif product
		descriptionRgbComposite="Amplitude Change RGB Composite"
		outputRgbCompositeNameTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaMasterSlaveComposite}" "${descriptionRgbComposite}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Combined RGB product properties file created: ${outputRgbCompositeNameTIF_properties}"
		# publish the ESA SNAP results
		ciop-log "INFO" "Publishing Output Products" 
		ciopPublishOut=$( ciop-publish -m "${OUTPUTDIR}"/* )
	else
		### FULL RESOLUTION PRODUCTS GENERATION
		# report activity in the log
    	ciop-log "INFO" "Pixel spacing is: {pixelSpacingInMeter}, its < 30, therefore chosen for bandmath method of creating visualization products."

		ciop-log "INFO" "Creating full resolution visualization products"
		## Create RGB composite R=coherence G=sigmaAverage B=null
		rgbCompositeNameTIF=${rgbCompositeName}.tif
		# Full Resolution product 8 bit encoded 
		rgbCompositeNameFullResTIF=${rgbCompositeName}.rgb.tif
		green=${TMPDIR}/green_output.tif
		red=${TMPDIR}/red_output.tif
		blue=${TMPDIR}/blue_output.tif
		#report activity in the log
		ciop-log "INFO" "Prepare snap visualization bands for coherence and sigma on ${rgbCompositeNameTIF} with coherenceband set as: ${coherenceBand} resulting in ${green} and ${red} ${blue}"
		# Pepare the snap request
		SNAP_REQUEST=$( create_snap_visualization_bands_coh_sigma "${rgbCompositeNameTIF}" "${green}" "${blue}" "${coherenceBand}" "${red}" )
		[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
		[ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
		#report activity in the log
		ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
		#report activity in the log
		ciop-log "INFO" "Invoking SNAP-gpt on the generated request file to perform visualization preprocessing for coherence and sigma bands"  
		#check the exit code
		gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
		# check the exit code
		[ $? -eq 0 ] || return $ERR_SNAP
		rgbMergeOutputTIF=${rgbCompositeName}.merged.tif
		ciop-log "INFO" "Invoking gdalmerge on seperate band results of snap bandmath"
		gdal_merge.py -separate -n 0 -a_nodata 0 -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" "${red}" "${green}" "${blue}" -o ${rgbMergeOutputTIF} -co BIGTIFF=YES
		returnCode=$?
		[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
		#reprojection
		ciop-log "INFO" "Invoking gdalwarp on gdalmerge+translate result"
		gdalwarp -ot Byte -t_srs EPSG:3857 -srcnodata 0 -dstnodata 0 -dstalpha -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" ${rgbMergeOutputTIF} ${rgbCompositeNameFullResTIF} -co BIGTIFF=YES
		# gdalwarp -ot Byte -t_srs EPSG:3857 -r cubic ${rgbMergeOutputTIF} ${rgbCompositeNameFullResTIF}
		returnCode=$?
		[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
		# Add overviews
		ciop-log "INFO" "Invoking gdaladdo on gdalwarp+merge+translate result"
		gdaladdo -r average ${rgbCompositeNameFullResTIF} 2 4 8 16
		returnCode=$?
		[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
		rm ${pconvertOutRgbCompositeTIF}
		# PNG output
		rgbCompositeNameFullResPNG=${rgbCompositeName}.png
		#pconvert -f png -p ${TMPDIR}/coh_sigmaAvg_null.rgb -s 0,0 -o ${TMPDIR} ${rgbCompositeNameTIF} &> /dev/null
		# check the exit code
		[ $? -eq 0 ] || return $ERR_PCONVERT
		# output of pconvert
		pconvertOutRgbCompositePNG=${TMPDIR}/${rgbCompositeBasename}.png
		# remove black background
		ciop-log "INFO" "Invoking gdaltranslate to create png of ${rgbMergeOutputTIF}"

		gdal_translate -of png -scale -co worldfile=yes ${rgbMergeOutputTIF} ${pconvertOutRgbCompositePNG}
		convert ${pconvertOutRgbCompositePNG} -alpha set -channel RGBA -fill none -opaque black ${rgbCompositeNameFullResPNG}
		rm ${pconvertOutRgbCompositePNG}
		# remove physical product
		rm ${rgbCompositeNameTIF} ${rgbMergeOutputTIF}
		#Normally also removed here: ${rgbMergeOutputTIF}
		# visualization product is the unique generated output for the RGB combination
		mv ${rgbCompositeNameFullResTIF} ${rgbCompositeNameTIF}
		# Colorbar legend to be published 
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/coh_sigmaAvg_null_colormap.png
		# Output name of customized colorbar legend
		rgbCompositeColorbarOutput=${rgbCompositeName}.tif.legend.png
		cp ${colorbarInput} ${rgbCompositeColorbarOutput}
		## Full resolution image creation for Sigma Master product
		# Visualization product name
		sigmaMasterNameFullResTIF=${sigmaMasterName}.rgb.tif
		# Source band name 
		sourceBand=${sigmaMasterBand}_db
		# define min max values in dB for sigma visualization
		min_val=-15
		max_val=5
		# call function for visualization product generator 
		min_max_val=$( visualization_product_creator_one_band "${sigmaMasterName_TIF}" "${sourceBand}" "${min_val}" "${max_val}" "${sigmaMasterNameFullResTIF}" )
		retCode=$?
		[ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
		[ $retCode -eq 0 ] || return $retCode
		# Colorbar legend to be customized with product statistics
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/colorbar_gray.png #sample Gray Colorbar (as used by pconvert with single band products) colorbar image
		# Output name of customized colorbar legend
		sigmaMasterColorbarOutput=${sigmaMasterName}.tif.legend.png
		# colorbar description
		colorbarDescription="Sigma_0 Master [dB]"
		#Customize colorbar with product statistics
		retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${sigmaMasterColorbarOutput}" )
		## Full resolution image creation for Sigma Slave product
		# Visualization product name
		sigmaSlaveNameFullResTIF=${sigmaSlaveName}.rgb.tif
		# Source band name
		sourceBand=${sigmaSlaveBand}_db
		# call function for visualization product generator
		min_max_val=$( visualization_product_creator_one_band "${sigmaSlaveName_TIF}" "${sourceBand}" "${min_val}" "${max_val}" "${sigmaSlaveNameFullResTIF}" )
		retCode=$?
		[ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
		[ $retCode -eq 0 ] || return $retCode
		# Output name of customized colorbar legend
		sigmaSlaveColorbarOutput=${sigmaSlaveName}.tif.legend.png
		# colorbar description
		colorbarDescription="Sigma_0 Slave [dB]"
		# Customize colorbar with product statistics
		retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${sigmaSlaveColorbarOutput}" )
		## Full resolution image creation for Coeherence product
		# Visualization product name
		coherenceNameFullResTIF=${coherenceName}.rgb.tif
		# Build source band name for statistics computation
		sourceBand=${coherenceBand}
		# define percentiles min max values for coherence visualization
		min_val="pc2"
		max_val="pc96"
		# call function for visualization product generator
		min_max_val=$( visualization_product_creator_one_band "${coherenceName_TIF}" "${sourceBand}" "${min_val}" "${max_val}" "${coherenceNameFullResTIF}" )
		retCode=$?
		[ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
		[ $retCode -eq 0 ] || return $retCode
		# Colorbar legend to be customized with product statistics
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/colorbar_gray.png #sample Gray Colorbar (as used by pconvert with single band products) colorbar image
		# Output name of customized colorbar legend
		coherenceColorbarOutput=${coherenceName}.tif.legend.png
		# colorbar description
		colorbarDescription="Coherence"
		# Customize colorbar with product statistics
		retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${coherenceColorbarOutput}" )
		## Full resolution image creation for Sigma Average product
		# Visualization product name
		sigmaAverageNameFullResTIF=${sigmaAverageName}.rgb.tif
		# Build source band name for statistics computation
		sourceBand="sigmaAverage"
		# define min max values for sigma average visualization
		min_val=-15
		max_val=5
		# call function for visualization product generator
		min_max_val=$( visualization_product_creator_one_band "${sigmaAverageName_TIF}" "${sourceBand}" "${min_val}" "${max_val}" "${sigmaAverageNameFullResTIF}" )
		retCode=$?
		[ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
		[ $retCode -eq 0 ] || return $retCode
		# Colorbar legend to be customized with product statistics
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/colorbar_gray.png #sample Gray Colorbar (as used by pconvert with single band products) colorbar image
		# Output name of customized colorbar legend
		sigmaAverageColorbarOutput=${sigmaAverageName}.tif.legend.png
		# colorbar description
		colorbarDescription="Sigma_0 Average [dB]"
		#Customize colorbar with product statistics
		retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${sigmaAverageColorbarOutput}" )
		## Full resolution image creation for Sigma Difference product
		# Visualization product name
		sigmaDiffNameFullResTIF=${sigmaDiffName}.rgb.tif
		# Build source band name for statistics computation
		sourceBand="sigmaDiff"
		# define min max percebtiles values for sigma average visualization
		min_val="pc2"
		max_val="pc96"
		# call function for visualization product generator
		min_max_val=$( visualization_product_creator_one_band "${sigmaDiffName_TIF}" "${sourceBand}" "${min_val}" "${max_val}" "${sigmaDiffNameFullResTIF}" )
		retCode=$?
		[ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
		[ $retCode -eq 0 ] || return $retCode
		# Colorbar legend to be customized with product statistics
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/colorbar_gray.png #sample Gray Colorbar (as used by pconvert with single band products) colorbar image
		# Output name of customized colorbar legend
		sigmaDiffColorbarOutput=${sigmaDiffName}.tif.legend.png
		# colorbar description
		colorbarDescription="Sigma_0 Difference [dB]"
		# Customize colorbar with product statistics
		retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${sigmaDiffColorbarOutput}" )
		## Create RGB composite R=sigma master G=sigma slave B=sigma slave
		sigmaMasterSlaveCompositeTIF=${sigmaMasterSlaveComposite}.tif
		sigmaMasterSlaveCompositeClip_TIF=${sigmaMasterSlaveComposite}_clip.tif
		# Clip values between -15 and +5 dB 
		# report activity in the log
		ciop-log "INFO" "Preparing SNAP request file to clip Backscatter master and slave values"
		min_val=-15
		max_val=5
		# prepare the SNAP request
		SNAP_REQUEST=$( create_snap_sigmaMasterSlave_clip "${sigmaMasterSlaveCompositeTIF}" "${sigmaMasterBand}_db" "${sigmaSlaveBand}_db" "${min_val}" "${max_val}" "${sigmaMasterSlaveCompositeClip_TIF}" )
		[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
		[ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
		# report activity in the log
		ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
		# report activity in the log
		ciop-log "INFO" "Invoking SNAP-gpt on the generated request file clip Backscatter master and slave values"
		# invoke the ESA SNAP toolbox
		gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
		# check the exit code
		[ $? -eq 0 ] || return $ERR_SNAP
		# Full Resolution product 8 bit encoded
		# The output for the RGB combination is a couple of visualization products
		# - A GeoTiff to be displayed on the map
		# - A PNG file  
		rm ${sigmaMasterSlaveCompositeTIF}
		sigmaMasterSlaveCompositeFullResTIF=${sigmaMasterSlaveCompositeTIF}
		#Creation names output tif and png
		pconvertOutTIF=${TMPDIR}/${sigmaMasterSlaveCompositeBasename}_clip.tif
		pconvertOutPNG=${TMPDIR}/${sigmaMasterSlaveCompositeBasename}_clip.png    

		ciop-log "INFO" "Invoking gdaltranslate to create a sigma master slave composite clip tif"
		#Create a tif from making a sigma master slave composite, with gdal translate and perform scaling		
		gdal_translate -ot Byte -of GTiff -b 2 -b 1 -b 1 -scale -15 0 0 255 -co PHOTOMETRIC=RGB ${sigmaMasterSlaveCompositeClip_TIF}  ${pconvertOutTIF}	
		returnCode=$?
		[ $returnCode -eq 0 ] || return ${ERR_PCONVERT}
		# PNG creation
		ciop-log "INFO" "Invoking gdal to create a sigma master slave composite clip png"
		gdal_translate -of png -scale -co worldfile=yes ${pconvertOutTIF} ${pconvertOutPNG}

		# check the exit code
		returnCode=$?
		[ $returnCode -eq 0 ] || return ${ERR_PCONVERT}

		#[ $? -eq 0 ] || return $ERR_PCONVERT
		sigmaMasterSlaveCompositeFullResPNG=${sigmaMasterSlaveComposite}.png
		mv ${pconvertOutPNG} ${sigmaMasterSlaveCompositeFullResPNG}
		# reprojection
		ciop-log "INFO" "Invoking gdal to create a warp of sigma master slave composite clip tif"

		gdalwarp -ot Byte -t_srs EPSG:3857 -srcalpha -dstalpha -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" ${pconvertOutTIF} ${sigmaMasterSlaveCompositeFullResTIF} -co BIGTIFF=YES
		#Add overviews
		ciop-log "INFO" "Invoking gdal to create a gdaladdo of sigma master slave composite clip tif"
		gdaladdo -r average ${sigmaMasterSlaveCompositeFullResTIF} 2 4 8 16 
		returnCode=$?
		[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
		rm ${pconvertOutTIF}  ${sigmaMasterSlaveCompositeClip_TIF} 
		#Normally also removed here: ${sigmaMasterSlaveCompositeClip_TIF}
		# Colorbar legend to be customized with product statistics
		colorbarInput=$_CIOP_APPLICATION_PATH/gpt/rgb_cube_sigmaS_sigmaM_sigmaM.png # RGB cube
		# Output name of customized colorbar legend
		sigmaMasterSlaveCompositeColorbarOutput=${sigmaMasterSlaveComposite}.tif.legend.png
		# colorbar description
		colorbarDescription="Amplitude Change RGB Composite"
		#Customize colorbar with product statistics
		retVal=$(colorbarCreatorRGB "${colorbarInput}" "${colorbarDescription}" "${min_val}" "${max_val}" "${min_val}" "${max_val}" "${min_val}" "${max_val}" "${sigmaMasterSlaveCompositeColorbarOutput}" )

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
		# create properties file for coherence tif product
		descriptionCoh="Coherence computed on input SLC couple"
		outputCohTIF_properties=$( propertiesFileCratorTIF_IFG "${coherenceName}" "${descriptionCoh}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Coherence properties file created: ${outputCohTIF_properties}"
		# create properties file for Intensity average tif product
		descriptionSigmaAverage="Intensity average in dB of input SLC couple"
		outputSigmaAverageTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaAverageName}" "${descriptionSigmaAverage}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Backscatter average properties file created: ${outputSigmaAverageTIF_properties}"
		# create properties file for Intensity difference average tif product
		descriptionSigmaDiff="Intensity difference in dB of input SLC couple"
		outputSigmaDiffTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaDiffName}" "${descriptionSigmaDiff}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Backscatter difference properties file created: ${outputSigmaDiffTIF_properties}"
		# create properties file for Intensity Master tif product
		descriptionSigmaMaster="Intensity in dB of the Master product"
		outputSigmaMasterTIF_properties=$( propertiesFileCratorTIF_OneBand "${sigmaMasterName}" "${descriptionSigmaMaster}" "${dateMaster}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Master Backscatter properties file created: ${outputSigmaMasterTIF_properties}"
		# create properties file for Intensity Slave tif product
		descriptionSigmaSlave="Intensity in dB of the Slave product"
		outputSigmaSlaveTIF_properties=$( propertiesFileCratorTIF_OneBand "${sigmaSlaveName}" "${descriptionSigmaSlave}" "${dateSlave}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Slave Backscatter properties file created: ${outputSigmaSlaveTIF_properties}"
		# create properties file for RGB composite tif product
		descriptionRgbComposite="Coherence and Intensity RGB composite"
		outputRgbCompositeNameTIF_properties=$( propertiesFileCratorTIF_IFG "${rgbCompositeName}" "${descriptionRgbComposite}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Combined RGB product properties file created: ${outputRgbCompositeNameTIF_properties}"    
		# create properties file for RGB composite tif product
		descriptionRgbComposite="Amplitude Change RGB Composite"
		outputRgbCompositeNameTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaMasterSlaveComposite}" "${descriptionRgbComposite}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}" )
		# report activity in the log
		ciop-log "DEBUG" "Combined RGB product properties file created: ${outputRgbCompositeNameTIF_properties}"
                # publish the ESA SNAP results

	        ciop-log "INFO" "Publishing Output Products"
                ciopPublishOut=$( ciop-publish -m "${OUTPUTDIR}"/* )

    fi
	
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

declare -a inputfiles

while read inputfile; do
    inputfiles+=("${inputfile}") # Array append
done

main ${inputfiles[@]}
res=$?
[ ${res} -ne 0 ] && exit ${res}

exit $SUCCESS
