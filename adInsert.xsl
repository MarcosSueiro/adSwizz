<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs" version="2.0">

    <xsl:mode on-no-match="deep-skip"/>
    <xsl:output indent="yes"/>
    <!-- Take a wav file with markers 
        and output the AdSwizz syntax to DAVID's comment field. 
        
        Enter the wav's URI in the wavURI parameter 
        and run it against any xml file.
        
        The markers can come from DAVID's database, 
        a cue chunk export from BWF MetaEdit, 
        or a combination of both. 
        You can then just drag the resulting .DBX file into DAVID.

        NOTE: We do not recommend adding maarkers with DAVID's EasyTrack, 
        as its behaviour seems rather erratic with respect to markers, 
        -and its markers are not compliant with the standard.
        
        A few caveats:

        The script assumes that DAVID's sidecar .DBX file lives in the same directory
        The script assumes that the BWF MetaEdit cue export is named {filename}.cue.xml and is in the same directory (this is the default behaviour for the CLI export)
        For files without a sidecar .DBX file, the default sample rate is 44100; 
        other sample rates need to be entered manually -->

    <xsl:param name="wavURI" select="'U:\ArchDept\markerTests\Test All DigaMarkers.WAV'"/>

    <xsl:param name="adKeyword" select="'AD'"/>
    <!-- Add this keyword to the title field in the DAVID markers 
        or the "Name" field in Audition-->
    <xsl:param name="destinationFolder" select="'U:/ArchDept/'"/>
    <!-- Where you want the resulting .DBX file -->
    <xsl:param name="defaultSampleRate" select="44100" as="xs:integer"/>
    <!-- ATTENTION! This is a *presumed* sample rate, please neter correct number -->

    <xsl:param name="filename" select="tokenize($wavURI, '\\')[last()]"/>
    <xsl:param name="filenameNoExt" select="substring($filename, 1, string-length($filename) - 4)"/>
    <xsl:param name="filenameAppend" select="'_wMarkers'"/>


    <xsl:template match="*[ends-with($wavURI, '.WAV')]">
        <xsl:param name="wavURI" select="$wavURI[ends-with(., '.WAV')]"/>
        <xsl:param name="wavURIFixed" select="translate($wavURI, '\', '/')"/>
        <xsl:param name="dbxURI"
            select="concat('file:///', substring($wavURIFixed, 1, string-length($wavURIFixed) - 4), '.DBX')"/>
        <xsl:param name="cueDocumentURI" select="concat('file:///', $wavURIFixed, '.cue', '.xml')"/>

        <xsl:variable name="dbxExists" select="doc-available($dbxURI)"/>
        <xsl:variable name="cueDocExists" select="doc-available($cueDocumentURI)"/>

        <xsl:variable name="originalDbx" select="document($dbxURI)[$dbxExists]"/>
        <xsl:variable name="cueDoc" select="document($cueDocumentURI)[$cueDocExists]"/>
        <xsl:variable name="dbxTimes">
            <xsl:for-each
                select="$originalDbx/ENTRIES/ENTRY[CLASS = 'Audio']/MEDIUM/FILE[TYPE = 'Audio']/SUBCLIPS/SUBCLIP[TITLE = $adKeyword]/STARTPOS">
                <time>
                    <xsl:call-template name="time-to-milliseconds">
                        <xsl:with-param name="time" select="."/>
                    </xsl:call-template>
                </time>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="sampleRate"
            select="
                if ($dbxExists) then
                    xs:integer($originalDbx/ENTRIES/ENTRY/SAMPLERATE)
                else
                    $defaultSampleRate"/>
        <xsl:variable name="cueTimes">
            <xsl:for-each select="$cueDoc/Cues/Cue[Label = $adKeyword]">
                <time>
                    <xsl:value-of select="Position div $sampleRate * 1000"/>
                </time>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="allTimes">
            <times>
                <xsl:copy-of select="$dbxTimes | $cueTimes"/>
            </times>
        </xsl:variable>
        <xsl:variable name="adSwizzCode">
            <xsl:apply-templates select="$allTimes/times/time" mode="adSwizzCoding">
                <xsl:sort/>
            </xsl:apply-templates>
        </xsl:variable>
        <xsl:variable name="newFilename"
            select="concat('file:///', $destinationFolder, $filenameNoExt, $filenameAppend, '.DBX')"/>
        <xsl:copy-of select="$adSwizzCode"/>
        <xsl:result-document href="{$newFilename}">
            <ENTRIES>
                <ENTRY>
                    <REMARK>
                        <xsl:value-of select="$adSwizzCode"/>
                    </REMARK>
                    <xsl:copy-of
                        select="$originalDbx/ENTRIES/ENTRY[CLASS = 'Audio']/*[not(local-name() = 'REMARK')]"
                    />
                </ENTRY>
            </ENTRIES>
        </xsl:result-document>
    </xsl:template>

    <xsl:template name="time-to-milliseconds">
        <xsl:param name="time"/>
        <xsl:param name="h" select="xs:integer(substring-before($time, ':'))"/>
        <xsl:param name="m" select="xs:integer(substring-before(substring-after($time, ':'), ':'))"/>
        <xsl:param name="ms"
            select="xs:integer(translate(substring-after(substring-after($time, ':'), ':'), '.', ''))"/>

        <xsl:value-of select="1000 * (3600 * $h + 60 * $m) + $ms"/>
    </xsl:template>

    <xsl:template name="adSwizzCoding" match="time" mode="adSwizzCoding">
        <xsl:param name="milliseconds" select="."/>
        <xsl:value-of select="'AIS_AD_BREAK_'"/>
        <xsl:value-of select="position()"/>
        <xsl:value-of select="'='"/>
        <xsl:value-of select="$milliseconds"/>
        <xsl:value-of select="',0;'"/>
    </xsl:template>




</xsl:stylesheet>