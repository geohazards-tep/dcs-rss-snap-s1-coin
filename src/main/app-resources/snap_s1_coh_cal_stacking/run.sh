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
        *)                      	msg="Unknown error";;
    esac

   [ ${retval} -ne 0 ] && ciop-log "ERROR" "Error ${retval} - ${msg}, processing aborted" || ciop-log "INFO" "${msg}"
   [ ${retval} -ne 0 ] && hadoop dfs -rmr $(dirname "${inputfiles[0]}")
   exit ${retval}
}

trap cleanExit EXIT

function create_snap_request_mrg_ml_tc(){

#function call: SNAP_REQUEST=$( create_snap_request_mrg_ml_tc "${inputDIM[@]}" "${polarisation}" "${nAzLooks}" "${nRgLooks}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${output_Mrg_Ml_Tc}" )      

    # function which creates the SNAP request file for the Topsar subswath merging,  
    # multilooking and terrain correction. It returns the path to the request file.
  
    # get number of inputs    
    inputNum=$#
    
    #conversion of first input to array of strings and get all the remaining input
    local -a inputfiles
    local polarisation
    local nAzLooks
    local nRgLooks
    local demType
    local pixelSpacingInMeter
    local mapProjection
    local output_Mrg_Ml_Tc
 
    # first input file always equal to the first function input
    inputfiles+=("$1")
    
    if [ "$inputNum" -gt "10" ] || [ "$inputNum" -lt "8" ]; then
        return ${SNAP_REQUEST_ERROR}
    elif [ "$inputNum" -eq "8" ]; then
        polarisation=$2
        nAzLooks=$3
	nRgLooks=$4
	demType=$5
	pixelSpacingInMeter=$6
	mapProjection=$7
        output_Mrg_Ml_Tc=$8
    elif [ "$inputNum" -eq "9" ]; then
        inputfiles+=("$2")
        polarisation=$3
        nAzLooks=$4
	nRgLooks=$5
	demType=$6
	pixelSpacingInMeter=$7
	mapProjection=$8
        output_Mrg_Ml_Tc=$9
    elif [ "$inputNum" -eq "10" ]; then
        inputfiles+=("$2")
        inputfiles+=("$3")
        polarisation=$4
        nAzLooks=$5
	nRgLooks=$6
	demType=$7
	pixelSpacingInMeter=$8
	mapProjection=$9
        output_Mrg_Ml_Tc=${10}
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
  <node id="Terrain-Correction">
    <operator>Terrain-Correction</operator>
    <sources>
      <sourceProduct refid="Multilook"/>
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
# function call SNAP_REQUEST=$(  create_snap_sigmaAvrgDiff_bandExtract "${stackProduct_DIM}" "${sigmaMasterBand}" "${sigmaSlaveBand}" "${coherenceBand}" "${sigmaDiffName}" "${sigmaAverageName}" "${sigmaMasterName}" "${sigmaSlaveName}" "${coherenceName}" )
   # function which creates the SNAP request file for the computation of backscatter average and difference in dB and to extract the coherence band from the input stack product.
   # It returns the path to the request file.

   # get number of inputs
   inputNum=$#
   # check on number of inputs
   if [ "$inputNum" -ne "9" ]; then
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
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations/>
      <sourceBands>${sigmaMasterBand}</sourceBands>
      <bandNamePattern/>
    </parameters>
  </node>
  <node id="BandSelect(3)">
    <operator>BandSelect</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations/>
      <sourceBands>${sigmaSlaveBand}</sourceBands>
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
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandSelect(3)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${sigmaSlaveName}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
      <displayPosition x="34.0" y="113.0"/>
    </node>
    <node id="BandMaths">
      <displayPosition x="304.0" y="32.0"/>
    </node>
    <node id="BandMaths(2)">
      <displayPosition x="300.0" y="110.0"/>
    </node>
    <node id="LinearToFromdB">
      <displayPosition x="148.0" y="32.0"/>
    </node>
    <node id="LinearToFromdB(2)">
      <displayPosition x="143.0" y="111.0"/>
    </node>
    <node id="Write(2)">
      <displayPosition x="433.0" y="111.0"/>
    </node>
    <node id="Write(3)">
      <displayPosition x="434.0" y="191.0"/>
    </node>
    <node id="BandSelect">
      <displayPosition x="165.0" y="189.0"/>
    </node>
    <node id="Write">
      <displayPosition x="436.0" y="32.0"/>
    </node>
  </applicationData>
</graph>
EOF

[ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}


}


function propertiesFileCratorPNG(){
#function call: propertiesFileCratorPNG "${outputProductTif}" "${outputProductPNG}" "${legendPng}"

    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -lt "2" ] || [ "$inputNum" -gt "3" ]; then
        return ${ERR_PROPERTIES_FILE_CREATOR}
    fi

    # function which creates the .properties file to attach to the output png file
    local outputProductTif=$1
    local outputProductPNG=$2
    if [ "$inputNum" -eq "3" ]; then
         legendPng=$3
    fi 

	
    # extracttion coordinates from gdalinfo
    # from a string like "Upper Left  (  13.0450832,  42.4802388) ( 13d 2'42.30"E, 42d28'48.86"N)" is extracted "13.0450832 42.4802388"
    lon_lat_1=$( gdalinfo "${outputProductTif}" | grep "Lower Left"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
    lon_lat_2=$( gdalinfo "${outputProductTif}" | grep "Upper Left"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
    lon_lat_3=$( gdalinfo "${outputProductTif}" | grep "Upper Right"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
    lon_lat_4=$( gdalinfo "${outputProductTif}" | grep "Lower Right"  | tr -s " " | sed 's#.*(\(.*\), \(.*\)) (.*#\1 \2#g' | sed 's#^ *##g' )
	
    outputProductPNG_basename=$(basename "${outputProductPNG}")
    properties_filename=${outputProductPNG}.properties
    if [ "$inputNum" -eq "2" ]; then	

	cat << EOF > ${properties_filename}
title=${outputProductPNG_basename}
geometry=POLYGON(( ${lon_lat_1}, ${lon_lat_2}, ${lon_lat_3}, ${lon_lat_4}, ${lon_lat_1} ))
EOF
    else
 	cat << EOF > ${properties_filename}
image_url=./${legendPng}
title=${outputProductPNG_basename}
geometry=POLYGON(( ${lon_lat_1}, ${lon_lat_2}, ${lon_lat_3}, ${lon_lat_4}, ${lon_lat_1} ))
EOF
    fi

    [ $? -eq 0 ] && {
        echo "${properties_filename}"
        return 0
    } || return ${ERR_PROPERTIES_FILE_CREATOR}

}

function propertiesFileCratorTIF_IFG(){
# function call propertiesFileCratorTIF_IFG "${outputProductTif}" "${description}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}"
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "8" ]; then
        return ${ERR_PROPERTIES_FILE_CREATOR}
    fi

    # function which creates the .properties file to attach to the output tif file
    local outputProductTif=$1
    local description=$2
    local dateStart=$3
    local dateStop=$4
    local dateDiff_days=$5 
    local polarisation=$6
    local snapVersion=$7
    local processingTime=$8

    outputProductTIF_basename=$(basename "${outputProductTif}")
    properties_filename=${outputProductTif}.properties

    cat << EOF > ${properties_filename}
title=${outputProductTIF_basename}
description=${description}
dateMaster=${dateStart}
dateSlave=${dateStop}
dateDiff_days=${dateDiff_days}
polarisation=${polarisation}
snapVersion=${snapVersion}
processingTime=${processingTime}
EOF

    [ $? -eq 0 ] && {
        echo "${properties_filename}"
        return 0
    } || return ${ERR_PROPERTIES_FILE_CREATOR}

}

function propertiesFileCratorTIF_OneBand(){
# function call propertiesFileCratorTIF_OneBand "${outputProductTif}" "${description}" "${date}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}"
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "6" ]; then
        return ${ERR_PROPERTIES_FILE_CREATOR}
    fi

    # function which creates the .properties file to attach to the output tif file
    local outputProductTif=$1
    local description=$2
    local date=$3
    local polarisation=$4
    local snapVersion=$5
    local processingTime=$6

    outputProductTIF_basename=$(basename "${outputProductTif}")
    properties_filename=${outputProductTif}.properties

    cat << EOF > ${properties_filename}
title=${outputProductTIF_basename}
description=${description}
productDate=${date}
polarisation=${polarisation}
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
# function call: colorbarCreator $inputColorbar $statsFile $outputColorbar

    #function that put value labels to the JET colorbar legend input depending on the
    # provided product statistics   

     # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "3" ] ; then
        return ${ERR_COLORBAR_CREATOR}
    fi
    
    #get input
    local inputColorbar=$1
    local statsFile=$2
    local outputColorbar=$3

    # get maximum from stats file
    maximum=$(cat "${statsFile}" | grep world | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 5)
    #get minimum from stats file
    minimum=$(cat "${statsFile}" | grep world | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 7)
    #compute colorbar values
    rangeWidth=$(echo "scale=5; $maximum-$minimum" | bc )
    red=$(echo "scale=5; $minimum" | bc | awk '{printf "%.2f", $0}')
    yellow=$(echo "scale=5; $minimum+$rangeWidth/4" | bc | awk '{printf "%.2f", $0}')
    green=$(echo "scale=5; $minimum+$rangeWidth/2" | bc | awk '{printf "%.2f", $0}')
    cyan=$(echo "scale=5; $minimum+$rangeWidth*3/4" | bc | awk '{printf "%.2f", $0}')    
    blue=$(echo "scale=5; $maximum" | bc | awk '{printf "%.2f", $0}')
    
    #add color values
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/LucidaTypewriterBold.ttf" -fill black -draw "text 7,100 \"$red\" " $inputColorbar $outputColorbar
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/LucidaTypewriterBold.ttf" -fill black -draw "text 76,100 \"$yellow\" " $outputColorbar $outputColorbar
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/LucidaTypewriterBold.ttf" -fill black -draw "text 147,100 \"$green\" " $outputColorbar $outputColorbar 
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/LucidaTypewriterBold.ttf" -fill black -draw "text 212,100 \"$cyan\" " $outputColorbar $outputColorbar
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/LucidaTypewriterBold.ttf" -fill black -draw "text 278,100 \"$blue\" " $outputColorbar $outputColorbar

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

    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file for merging, multilooking and terrain correction processing (Coherence product)"

    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_mrg_ml_tc "${inputCohDIM[@]}" "${polarisation}" "${nAzLooks}" "${nRgLooks}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${coherence_Mrg_Ml_Tc}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
        
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for merging, multilooking and terrain correction processing (Coherence product)"

    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP

    ## Backscatter
    # output products filename
    sigma_Mrg_Ml_Tc=${TMPDIR}/target_IW_${polarisation}_Split_Orb_Cal_Back_ESD_Deb_Merge_ML_TC

    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file for merging, multilooking and terrain correction processing (Backscatter product)"

    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_mrg_ml_tc "${inputSigmaDIM[@]}" "${polarisation}" "${nAzLooks}" "${nRgLooks}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${sigma_Mrg_Ml_Tc}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for merging, multilooking and terrain correction processing (Backscatter product)"

    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST &> /dev/null
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
    
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file to create stack with Master Backscatter, Slave Backscatter and Coherence products"

    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP

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
    coeherenceBasename=coherence_IW_${polarisation}_${dateMaster}_${dateSlave}
    coherenceName=${OUTPUTDIR}/${coeherenceBasename}

    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file to Backscatter average and difference computation (in dB) and individual bands extraction from stack product"

    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_sigmaAvrgDiff_bandExtract "${stackProduct_DIM}" "${sigmaMasterBand}" "${sigmaSlaveBand}" "${coherenceBand}" "${sigmaDiffName}" "${sigmaAverageName}" "${sigmaMasterName}" "${sigmaSlaveName}" "${coherenceName}")
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file to Backscatter average and difference computation (in dB) and individual bands extraction from stack product"

    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP

    ### COMPOSITE RGB QUICK LOOK GENERATION

    # report activity in the log
    ciop-log "INFO" "Creating composite RGB quick-look from coherence product (=Red), backscatter average (=Green) and backscatter difference (=Blue)"

    ## Create quick-look for each tif output product
    # coherence product
    coherenceName_TIF=${coherenceName}.tif
    pconvert -f png -b 1 -W 2048 -o "${TMPDIR}" "${coherenceName_TIF}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # sigma average product
    sigmaAverageName_TIF=${sigmaAverageName}.tif
    pconvert -f png -b 1 -W 2048 -o "${TMPDIR}" "${sigmaAverageName_TIF}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # sigma difference product
    sigmaDiffName_TIF=${sigmaDiffName}.tif
    pconvert -f png -b 1 -W 2048 -o "${TMPDIR}" "${sigmaDiffName_TIF}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    ## Create RGB composite R=coherence G=sigmaAverage B=sigmaDiff 
    combinedRGB=combined_coh_sigmaAvrg_sigmaDiff_IW_${polarisation}_${dateMaster}_${dateSlave}
    convert -combine ${TMPDIR}/${coeherenceBasename}.png ${TMPDIR}/${sigmaAverageBasename}.png ${TMPDIR}/${sigmaDiffBasename}.png ${TMPDIR}/RGB.png 
    # remove black background 
    convert ${TMPDIR}/RGB.png -alpha set -channel RGBA -fill none -opaque black ${OUTPUTDIR}/${combinedRGB}.png 

    # report activity in the log
    ciop-log "INFO" "Creating properties files"

    #create .properties file for displacement png quick-look
    outCombinedRGB_properties=$( propertiesFileCratorPNG "${coherenceName_TIF}" "${OUTPUTDIR}/${combinedRGB}.png" )

    # report activity in the log
    ciop-log "DEBUG" "Composite RGB properties file created: ${outCombinedRGB_properties}"
    # get timing info for the tif properties file
    dateStart_s=$(date -d "${dateMaster}" +%s)
    dateStop_s=$(date -d "${dateSlave}" +%s)
    dateDiff_s=$(echo "scale=0; $dateStop_s-$dateStart_s" | bc )
    secondsPerDay="86400"
    dateDiff_days=$(echo "scale=0; $dateDiff_s/$secondsPerDay" | bc )
    processingTime=$( date )

    # create properties file for coherence tif product
    descriptionCoh="Coherence product computed on the input SLC couple"
    outputCohTIF_properties=$( propertiesFileCratorTIF_IFG "${coherenceName_TIF}" "${descriptionCoh}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Coherence properties file created: ${outputCohTIF_properties}"

    # create properties file for Intensity average tif product
    descriptionSigmaAverage="Intensity average in dB computed on the input SLC couple"
    outputSigmaAverageTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaAverageName_TIF}" "${descriptionSigmaAverage}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Backscatter average properties file created: ${outputSigmaAverageTIF_properties}"

    # create properties file for Intensity difference average tif product
    descriptionSigmaDiff="Intensity difference in dB computed on the input SLC couple"
    outputSigmaDiffTIF_properties=$( propertiesFileCratorTIF_IFG "${sigmaDiffName_TIF}" "${descriptionSigmaDiff}" "${dateMaster}" "${dateSlave}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Backscatter difference properties file created: ${outputSigmaDiffTIF_properties}"

    # create properties file for Intensity average tif product
    descriptionSigmaMaster="Intensity in dB of the Master product"
    sigmaMasterName_TIF=${sigmaMasterName}.tif
    outputSigmaMasterTIF_properties=$( propertiesFileCratorTIF_OneBand "${sigmaMasterName_TIF}" "${descriptionSigmaMaster}" "${dateMaster}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Master Backscatter properties file created: ${outputSigmaMasterTIF_properties}"

    # create properties file for Intensity average tif product
    descriptionSigmaSlave="Intensity in dB of the Slave product"
    sigmaSlaveName_TIF=${sigmaSlaveName}.tif
    outputSigmaSlaveTIF_properties=$( propertiesFileCratorTIF_OneBand "${sigmaSlaveName_TIF}" "${descriptionSigmaSlave}" "${dateSlave}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Slave Backscatter properties file created: ${outputSigmaSlaveTIF_properties}"

    # publish the ESA SNAP results
    ciop-log "INFO" "Publishing Output Products" 
    ciopPublishOut=$( ciop-publish -m "${OUTPUTDIR}"/* )
    # cleanup temp dir and output dir 
    rm -rf  "${TMPDIR}"/* "${OUTPUTDIR}"/* 
    # cleanup output products generated by the previous task
    for index in `seq 0 $inputfilesNum`;
    do
    	hadoop dfs -rmr "${inputfiles[$index]}"     	
    done

    return ${SUCCESS}
}

# create the output folder to store the output products and export it
mkdir -p ${TMPDIR}/output
export OUTPUTDIR=${TMPDIR}/output
mkdir -p ${TMPDIR}/input
export INPUTDIR=${TMPDIR}/input

declare -a inputfiles

while read inputfile; do
    inputfiles+=("${inputfile}") # Array append
done

main ${inputfiles[@]}
res=$?
[ ${res} -ne 0 ] && exit ${res}

exit $SUCCESS
