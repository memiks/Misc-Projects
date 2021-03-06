#spacenearuploader.pl - grabs whitestar balloon data, tests it then constructs a WB8ELK2 string for use with spacenear.us.
#Copyright (C) 2011  James Coxon, jacoxon@gmail.com
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

# use LWP::Simple;
use LWP::UserAgent;
use Geo::Coordinates::DecimalDegrees;
use Time::Local;


$oldepoch = 0;
$count = 0;
$validdata = 0;
$timecount = 21;

#---------------------------------------------------------------------
# RPad
#---------------------------------------------------------------------
# Pads a string on the right end to a specified length with a specified
# character and returns the result.  Default pad char is space.
#---------------------------------------------------------------------
sub RPad {
	
	local($str, $len, $chr) = @_;
	
	$chr = " " unless (defined($chr));
    
	return substr($str . ($chr x $len), 0, $len);
	
} # RPad

#---------------------------------------------------------------------
# LPad
#---------------------------------------------------------------------
# Pads a string on the left end to a specified length with a specified
# character and returns the result.  Default pad char is space.
#---------------------------------------------------------------------

sub LPad {
	
	local($str, $len, $chr) = @_;
	
	$chr = " " unless (defined($chr));
    
	return substr(($chr x $len) . $str, -1 * $len, $len);
	
} # LPad

#This section is used on start up - it pulls the latest data, runs through all the epochs, if epoch is > then the last 
#epoch it makes this the latest epoch.
#The aim is to avoid duplication, by grabbing all the epochs it means that the script will only look for new data after
#the time it was started.
my $ua = new LWP::UserAgent;
$ua->timeout(120);
my $url='http://50.16.222.54/publicData/getSample.php?latest';
my $request = new HTTP::Request('GET', $url);
my $response = $ua->request($request);
my $content = $response->content();
#print "$content\n";

@splitlines = split(/},/, $content);
@reversedlines = reverse(@splitlines);

foreach $completedata(@reversedlines){
	@splitdata = split(/,/, $completedata);
	
	foreach $datafield(@splitdata){
		@splitfield = split(/:/, $datafield);
		if($splitfield[1] ne "null"){
			$actualdata = substr( $splitfield[1], 1, - 1 );
		}
		else {
			$actualdata = $splitfield[1];
		}
		$datatitle = substr( $splitfield[0], 1, - 1 );
		
		if ($datatitle eq "epoch"){
			$epoch = $actualdata;
			if($epoch > $oldepoch){
				$oldepoch = $epoch;
			}
			print "$epoch, $oldepoch\n";
		}
	}
}


#Uncomment oldepoch if you want to test with static data, this just resets all the good work done by the previous section :-D
#$oldepoch = 0;

#This is the main loop, it grabs the data - checks the validity of the data and whether the flight computer has a fix, it then checks
# to see if the epoch > - if so it generates a telem string and uploads to the server.
while (1) {
	
	if($timecount >= 20) {
		my $tua = new LWP::UserAgent;
		$tua->timeout(120);
		my $url='http://50.16.222.54/publicData/getSample.php?settings=1';
		my $request = new HTTP::Request('GET', $url);
		my $response = $tua->request($request);
		my $content = $response->content();
		my @settingssplit = split(/\"/, $content); # "
		my @epochstart = split(/ /, $settingssplit[3]);
		#split up date
		my @epochstartdate = split(/-/, $epochstart[0]);
		my $epochyear = $epochstartdate[0];
		my $epochmonth = $epochstartdate[1];
		my $epochday = $epochstartdate[2];
		#split up time
		my @epochstarttime = split(/:/, $epochstart[1]);
		my $epochhour = $epochstarttime[0];
		my $epochminute = $epochstarttime[1];
		my $epochsecond = $epochstarttime[2];
		
		$unixepoch = timegm($epochsecond,$epochminute,$epochhour,$epochday,$epochmonth,$epochyear); 
		
		print "\nLAUNCH TIME: $epochyear, $epochmonth, $epochday, $epochhour, $epochminute, $epochsecond = $unixepoch\n";
		$timecount = 0;
	}
	else{
		$timecount = $timecount + 1;
	}

	#Here we grab the latest position report from robertharrison.org
	my $lp = new LWP::UserAgent;
	$lp->timeout(120);
	my $url='http://www.robertharrison.org/listen/lastpos.php';
	my $request = new HTTP::Request('GET', $url);
	my $response = $lp->request($request);
	my $content = $response->content();
	@lastpos = split(/,/, $content);
	if($lastpos[0] eq 'wb8elk2'){
		$lastpostime = $lastpos[4];
		@chars = split(//, $lastpostime);
		my $lpyear = "$chars[0]$chars[1]$chars[2]$chars[3]";
		my $lpmonth = "$chars[5]$chars[6]";
		my $lpday = "$chars[8]$chars[9]";
		my $lphour = "$chars[11]$chars[12]";
		my $lpminute = "$chars[14]$chars[15]";
		my $lpsecond = "$chars[17]$chars[18]";
		$lastposepoch = timegm($lpsecond,$lpminute,$lphour,$lpday,$lpmonth,$lpyear);
		print "\nLAST POS: $lpyear, $lpmonth, $lpday, $lphour, $lpminute, $lpsecond = $lastposepoch\n";
	}
	
	my $ua = new LWP::UserAgent;
	$ua->timeout(120);
	my $url='http://50.16.222.54/publicData/getSample.php?latest';
	my $request = new HTTP::Request('GET', $url);
	my $response = $ua->request($request);
	my $content = $response->content();
	#print "$content\n";
	
	print "\n";
	print scalar gmtime(time);
	print "\n";
	print "Current  Old      Total/Time  Lat               Lon                Upload\n";
	
	@splitlines = split(/},/, $content);
	@reversedlines = reverse(@splitlines);

	foreach $completedata(@reversedlines){
	@splitdata = split(/,/, $completedata);
	
	foreach $datafield(@splitdata){
		@splitfield = split(/:/, $datafield);
		if($splitfield[1] ne "null"){
			$actualdata = substr( $splitfield[1], 1, - 1 );
		}
		else {
			$actualdata = $splitfield[1];
		}
		$datatitle = substr( $splitfield[0], 1, - 1 );
		
		if ($actualdata eq "null"){
			$actualdata		= 0;
		}
		
		if ($datatitle eq "epoch"){
			$epoch = $actualdata;
		}
		if ($datatitle eq "latitude"){
			$latitude = $actualdata;
			($latdegrees, $latminutes) = decimal2dm($latitude);
			$nmealatitude = "$latdegrees$latminutes";
			$nmealatitude = substr( $nmealatitude, 0, 9 );
		}
		
		if ($datatitle eq "longitude"){
			$longitude = $actualdata;
			($londegrees, $lonminutes, $sign) = decimal2dm($longitude);
			#print "$londegrees $lonminutes $sign\n";
			if ($sign == -1 && $londegrees != 0){
				$londegrees = sprintf("%04d", $londegrees);
			}
			else {
				$londegrees = sprintf("%03d", $londegrees);
			}
			
			if(int($lonminutes < 10)){
				$lonminutes = "0$lonminutes";
			}
			
			if ($sign == -1 && $londegrees == 0) {
				$londegrees = "-$londegrees";
			}
			#print "$londegrees $lonminutes $sign\n";
			$nmealongitude = "$londegrees$lonminutes";
			$nmealongitude = substr( $nmealongitude, 0, 9 );
			#print "$nmealongitude\n";
		}
		
		if ($datatitle eq "altitude"){
			$altitude = $actualdata;
		}
		if ($datatitle eq "fix"){
			$fix = $actualdata;
		}
		if ($datatitle eq "pressure_fc"){
			$pressure_fc = $actualdata;
		}
		if ($datatitle eq "pressure_bb"){
			$pressure_bb = $actualdata;
		}
		if ($datatitle eq "pressure_bm"){
			$pressure_bm = $actualdata;
		}
		if ($datatitle eq "pressure_bt"){
			$pressure_bt = $actualdata;
		}
		if ($datatitle eq "temp_fc"){
			$temp_fc = $actualdata;
		}
		if ($datatitle eq "temp_ext"){
			$temp_ext = $actualdata;
		}
		if ($datatitle eq "temp_bb"){
			$temp_bb = $actualdata;
		}
		if ($datatitle eq "temp_bm"){
			$temp_bm = $actualdata;
		}
		if ($datatitle eq "temp_bt"){
			$temp_bt = $actualdata;
		}
		if ($datatitle eq "temp_batt"){
			$temp_batt = $actualdata;
		}
		if ($datatitle eq "humidity"){
			$humidity = $actualdata;
		}
		if ($datatitle eq "balloonValve"){
			$balloonValve = $actualdata;
		}
		if ($datatitle eq "ice"){
			$ice = $actualdata;
		}
		if ($datatitle eq "heading"){
			$heading = $actualdata;
		}
		if ($datatitle eq "speed"){
			$speed = $actualdata;
		}
		if ($datatitle eq "hdop"){
			$hdop = $actualdata;
		}
		if ($datatitle eq "climb"){
			$climb = $actualdata;
		}
		if ($datatitle eq "status"){
			$status = $actualdata;
		}
		if ($datatitle eq "dewpoint"){
			$dewpoint = $actualdata;
		}
		if ($datatitle eq "volts"){
			$volts = $actualdata;
		}
		if ($datatitle eq "acc_cur"){
			$acc_cur = $actualdata;
		}
		if ($datatitle eq "ballastValve"){
			$ballastValve = $actualdata;
		}
		if ($datatitle eq "balastRemaining"){
			$ballastRemaining = $actualdata;
		}
	}
	
	#Do some sanity checks
	#Check that latitude/longitude is not crazy
	$validdata = 1;

	if( ($latitude < 0.1) && ($latitude > -0.1) || ($longitude < 2.5) && ($longitude > -0.1) ){
		$validdata = 0;
	}

	$unixepoch = 1300576033;
	$totalepoch = $unixepoch + $epoch;

	#print "Calculate time of telem data: $unixepoch + $epoch = $totalepoch\n";
	#Pass this to the time library to convert into hour/min/secs
	@timeData = gmtime($totalepoch);
	foreach $timecomponent(@timeData){
		if($timecomponent < 10){
			$timecomponent = "0$timecomponent";
		}
	}
	
	print RPad($epoch, 9);
	print RPad($oldepoch, 9);
		#print RPad($totalepoch, 12);
	print RPad("$timeData[2]:$timeData[1]:$timeData[0]", 12);
	print RPad($latitude, 18);
	print RPad($longitude, 18);
	if($fix == 0 && $validdata == 1){
		if($epoch > $oldepoch && $totalepoch > $lastposepoch){
			print "    *\n";
			
			$oldepoch = $epoch;

			$count = $count + 1;
			
			$datastring = "WB8ELK2,$count,$timeData[2]:$timeData[1]:$timeData[0],$nmealatitude,$nmealongitude,$altitude,$fix,$ice;$temp_ext;$humidity;$speed;$climb;$ballastRemaining,0,0";
			
			#print "$datastring\n";
			
			my $rh = new LWP::UserAgent;
			$rh->timeout(120);
			my $response = $rh->post( "http://www.robertharrison.org/listen/listen.php", { 'string' => $datastring, 'identity' => "Orbcomm" } );
			
			#print "$response\n";
			sleep(2);
			}
		else{
			print "\n";
		}
	}
	else {
		print "\n";
		#print "No data uploaded fix = $fix and validdata = $validdata\n";
	}
}
	sleep(10);
}
