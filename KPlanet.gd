extends Node2D
class_name KPlanet

# big help from:   
#		https://janus.astro.umd.edu/cgi-bin/orbits/orbview.pl
#		https://scriptverse.academy/tutorials/c-program-newton-raphson.html
#		https://searchcode.com/codesearch/view/56537037/
# 		https://elainecoe.github.io/orbital-mechanics-calculator/formulas.html
#		https://orbital-mechanics.space/classical-orbital-elements/orbital-elements-and-the-state-vector.html
#		https://downloads.rene-schwarz.com/download/M002-Cartesian_State_Vectors_to_Keplerian_Orbit_Elements.pdf

var bigG=  30
export var mass = 100
export var mass2 = 50000

# ORBIT DEF
export var epoch:float = 0.0 # T
export var eccentricty:float = 0.0 # e
export var semiMajorAxis:float = 0.0 # a
export var argPeri:float = 0.0 # W or ARGP
export var trueAnomaly:float = 0.0 # v or 0 or f at T=0
export var orbitCounterClockwise:bool=true

#CALCED VALUES
var u = bigG * (mass+mass2)
var semiMinorAxis:float=0.0
var majorAxis:float=0.0
var minorAxis:float=0.0
var fDistFromC=0.0
var focus1Pos=Vector2.ZERO
var focus2Pos=Vector2.ZERO
var v1=Vector2.ZERO
var v2=Vector2.ZERO
var v3=Vector2.ZERO
var v4=Vector2.ZERO
var periAp=Vector2.ZERO
var apoAp=Vector2.ZERO
var periApDistFromF2=0.0
var apoApDistFromF2=0.0
var pprime1=Vector2.ZERO
var pprime2=Vector2.ZERO
var eccentricAnomaly=0.0
var meanAnomaly=0.0
var meanAnomalyMotion=0.0
var orbitalPeriod=0.0
var orbitalDistance=0.0
var orbitalPosition=Vector2.ZERO
var orbitalPositionGlobal=Vector2.ZERO

var orbitalVelocityMag=0.0
var orbitalVelocity=Vector2.ZERO
var orbitalVelocityf1=Vector2.ZERO
var orbitalVelocityf2=Vector2.ZERO
var orbitalVelocityNormal=Vector2.ZERO

func _ready():
	solveFromTrue()
#	solveFromStateVectors()
	update()
	
func setG(newBigG):
	bigG=  newBigG
	u = bigG * (mass+mass2)	
	
func guessE(M, eccentricAnomalyEstimate, maxRelativeError=0.000001, maxIterations=10):
	var e=0.0
	var meanAnomalyEstimate=0.0
	var relativeError=0.0
	var yQuad = 1
	
	if (M == 0 or eccentricty == 0):
		return M

	if (eccentricty == 1.0): # parabolic orbit - approx to hyperbolic
		# TODO parabolic/hyperbolic not done yet
		e = eccentricty + pow(10,6)
	else:
		e = eccentricty

	var i = 0
	while true:
		if (i >= maxIterations):
			break
			
		if ((i>0) && (abs(relativeError) <= abs(maxRelativeError))):
			break

		if (eccentricty < 1.0): # eliptical orbit

			#// calulate next estimate of the root of Keplers equation using Newtons method
			eccentricAnomalyEstimate = eccentricAnomalyEstimate - (eccentricAnomalyEstimate - (e * sin(eccentricAnomalyEstimate)) - M) / (1 - (e * cos(eccentricAnomalyEstimate)))
			
			#/* calculate estimate of mean anomaly from estimate of eccentric anomaly */
			meanAnomalyEstimate = eccentricAnomalyEstimate - (e * sin(eccentricAnomalyEstimate))

		else: # // hyperbolic orbit
			# TODO hyperbolic not done yet
			#/* sinh is not continuous over the range 0 to 2*pi, so it must be brought into the range -pi to pi */
			if (eccentricAnomalyEstimate > PI):
				eccentricAnomalyEstimate -= (2.0 * PI)
			#/* calculate next estimate of the root of Kepler's equation using Newton's method */
			eccentricAnomalyEstimate = eccentricAnomalyEstimate - (e * sinh(eccentricAnomalyEstimate) - eccentricAnomalyEstimate - M) / (e * cosh(eccentricAnomalyEstimate) - 1)
			#/* calculate estimate of mean anomaly from estimate of eccentric anomaly */
			meanAnomalyEstimate = e * sinh(eccentricAnomalyEstimate) - eccentricAnomalyEstimate

		#/* calculate relativeError */
		relativeError = 1.0 - meanAnomalyEstimate / M
		i = i+1
		
	#/* check range is in 0 to 2*pi */
	eccentricAnomalyEstimate = fmod(eccentricAnomalyEstimate , (2.0 * PI))
	if (eccentricAnomalyEstimate < 0):
		eccentricAnomalyEstimate += (2.0 * PI)

	return eccentricAnomalyEstimate*yQuad


func solveFromTrue(bypass_signals=false):
	var yQuad = 1
	
	if trueAnomaly <= 0.0:
		yQuad*=-1
		
	majorAxis = semiMajorAxis*2
	semiMinorAxis = semiMajorAxis* sqrt(1-(eccentricty*eccentricty))
	minorAxis = semiMinorAxis*2

	v1=Vector2(-semiMajorAxis,0)
	v2=Vector2(0,semiMinorAxis)
	v3=Vector2(semiMajorAxis,0)
	v4=Vector2(0,-semiMinorAxis)

	fDistFromC = sqrt((semiMajorAxis*semiMajorAxis)-(semiMinorAxis*semiMinorAxis))
	focus1Pos = Vector2(-fDistFromC,0)
	focus2Pos = Vector2(fDistFromC,0)

	orbitalPeriod=2*PI*sqrt((semiMajorAxis*semiMajorAxis*semiMajorAxis)/u) 
	if orbitalPeriod==0:
		get_parent().logMsg("ERR - orbitalPeriod is 0",true)
		return
	meanAnomalyMotion = (2*PI) / orbitalPeriod
	
	orbitalDistance=semiMajorAxis*((1-(pow(eccentricty,2)))/(1+eccentricty*cos(deg2rad(trueAnomaly))))  
	orbitalPosition.x=orbitalDistance*cos(deg2rad(trueAnomaly)) 
	orbitalPosition.y=-orbitalDistance*sin(deg2rad(trueAnomaly))
	
	orbitalPositionGlobal = to_global(orbitalPosition)
	
	if(orbitalDistance> 0 and semiMajorAxis>0):
		orbitalVelocityMag = sqrt(u * (  (2/orbitalDistance)-(1/semiMajorAxis)  )) # vis viva equation.

	var y2 = sqrt( pow(semiMajorAxis,2) - pow(-focus1Pos.x+orbitalPosition.x,2) )
	var y1 = -y2
	pprime1=Vector2(-focus1Pos.x+orbitalPosition.x, y1)
	pprime2=Vector2(-focus1Pos.x+orbitalPosition.x, y2)

	orbitalVelocityf1 = orbitalPosition.direction_to(focus1Pos+focus1Pos) *75
	orbitalVelocityf2 = orbitalPosition.direction_to(Vector2.ZERO) *75
	orbitalVelocityNormal = (orbitalVelocityf1+orbitalVelocityf2).normalized() *75
	if !orbitCounterClockwise:
		orbitalVelocity = orbitalVelocityNormal.normalized().tangent() *orbitalVelocityMag
	else:
		orbitalVelocity = orbitalVelocityNormal.normalized().tangent().tangent().tangent() *orbitalVelocityMag

	periAp=v3
	apoAp=v1
	periApDistFromF2 = focus2Pos.distance_to(periAp)
	apoApDistFromF2 = focus2Pos.distance_to(apoAp)

	# TODO: NOT USED
	var tmpVector = to_global(focus1Pos).direction_to(to_global(focus2Pos)).normalized()#.rotated(rotation) 
	var tmpargPeri = rad2deg(tmpVector.angle())
	if tmpargPeri < 0:
		tmpargPeri = 360+tmpargPeri
#	print(tmpargPeri)
	
	eccentricAnomaly=rad2deg(pprime2.angle_to_point(Vector2.ZERO) ) * yQuad
	meanAnomaly=rad2deg(deg2rad(eccentricAnomaly)-(eccentricty*sin(deg2rad(eccentricAnomaly))))

	var solveStr = ''
	solveStr+='t       '+str(epoch)+"\n"
	solveStr+='a       '+str(semiMajorAxis)+"\n"
	solveStr+='b       '+str(semiMinorAxis)+"\n"
	solveStr+='e       '+str(eccentricty)+"\n"
	solveStr+='argP    '+str(argPeri)+"\n"
	solveStr+='f1      '+str(focus1Pos)+"\n"
	solveStr+='f2      '+str(focus2Pos)+"\n"
	solveStr+='apo     '+str(apoAp)+"\n"
	solveStr+='peri    '+str(periAp)+"\n"
	solveStr+='apoApDistFromF2     '+str(apoApDistFromF2)+"\n"
	solveStr+='periApDistFromF2    '+str(periApDistFromF2)+"\n"
	solveStr+='0        '+str(trueAnomaly)+"\n"
	solveStr+='e0       '+str(eccentricAnomaly)+"\n"
	solveStr+='m0       '+str(meanAnomaly)+"\n"
	solveStr+='m0 n     '+str(meanAnomalyMotion)+"\n"
	solveStr+='oPos     '+str(orbitalPosition)+"\n"
	solveStr+='oPosGlob '+str(orbitalPositionGlobal)+"\n"
	solveStr+='oDist    '+str(orbitalDistance)+"\n"
	solveStr+='oVelMag  '+str(orbitalVelocityMag)+"\n"
	solveStr+='oVel     '+str(orbitalVelocity)+"\n"
	solveStr+='oVelNorm '+str(orbitalVelocityNormal)+"\n"
	solveStr+='oPeriod  '+str(orbitalPeriod)+"\n"
	solveStr+='mass1    '+str(mass)+"\n"
	solveStr+='mass2    '+str(mass2)+"\n"
	solveStr+='u        '+str(u)+"\n"
	solveStr+='G        '+str(bigG)+"\n"
	solveStr+='N2D pos  '+str(position)+"\n"
	solveStr+='N2D rot  '+str(rotation_degrees)+"\n"

	get_parent().logMsg(solveStr,true)
	
	if !bypass_signals:
		get_parent().bypass_slider_signals=true
		get_parent().get_node("CanvasLayer/HSliderSemiMajorAxis").value = semiMajorAxis
		get_parent().get_node('CanvasLayer/HSliderTrue').value = trueAnomaly
		get_parent().get_node('CanvasLayer/HSliderEccAnom').value = eccentricAnomaly
		get_parent().get_node('CanvasLayer/HSliderMeanAnom').value = meanAnomaly
		get_parent().get_node('CanvasLayer/HSliderEccent').value = eccentricty
		get_parent().get_node('CanvasLayer/HSliderArgPeri').value = argPeri
		get_parent().get_node('CanvasLayer/HSliderBigG').value = bigG
		
		get_parent().bypass_slider_signals=false


func solveFromEccentricAnom():
	
	# get TRUE ANOM from ECCENTRIC ANOM
	var tmpBeta = eccentricty / (1 + sqrt( 1- (eccentricty*eccentricty)  ))
	var tmptrueAnomaly = deg2rad(eccentricAnomaly) + (2*atan(  (tmpBeta*sin( deg2rad(eccentricAnomaly) ))  / ( 1 - (tmpBeta*cos( deg2rad(eccentricAnomaly) ))  )))   
	
	trueAnomaly = rad2deg(tmptrueAnomaly)
	solveFromTrue()

func solveFromMeanAnom():	
	var yQuad = 1
	if meanAnomaly < 0:
		yQuad = -1
	var tmpeccentricAnomaly = guessE(deg2rad(abs(meanAnomaly)),deg2rad(abs(meanAnomaly))) * yQuad
	
	eccentricAnomaly = rad2deg(tmpeccentricAnomaly)
	solveFromEccentricAnom()

func solveWithTime():	
	var meanAnomalyAtStart = 0.0
	var epochAtStart = 0.0
	
	# get MEAN ANOM at Time
	var tmpmeanAnomaly:float=  meanAnomalyAtStart + (meanAnomalyMotion * (epoch - epochAtStart))
	if orbitCounterClockwise==true:
		if (epoch - epochAtStart) > orbitalPeriod/2:
			tmpmeanAnomaly = -1*((2*PI)-tmpmeanAnomaly)
		
	if orbitCounterClockwise==false:
		tmpmeanAnomaly = (2*PI)-tmpmeanAnomaly 
		if (epoch - epochAtStart) < orbitalPeriod/2:
			tmpmeanAnomaly = -1*((2*PI)-tmpmeanAnomaly)

	meanAnomaly = rad2deg(tmpmeanAnomaly)
	solveFromMeanAnom()

func solveFromStateVectors():
	
#	orbitalPosition = Vector2(-446.895569, -561.350342)
#	orbitalVelocity = Vector2(505.510651, 114.472748)
	var tmporbitalPosition = Vector3(orbitalPosition.x, orbitalPosition.y,0)
	var tmporbitalVelocity = Vector3(orbitalVelocity.x, orbitalVelocity.y,0)
#	print(tmporbitalPosition)
#	print(tmporbitalVelocity)
	
#Step 1—Position and Velocity Magnitudes
	var r = tmporbitalPosition.length()
	var vel = tmporbitalVelocity.length()
	var velr = (tmporbitalPosition/r).dot(tmporbitalVelocity)
	var _velp = sqrt((vel*vel) - (velr*velr))
#	print(r)
#	print(vel)
#	print(velr)
#	print(velp)

#Step 2—Orbital Angular Momentum & SemiMajor Axis
	var hvec = tmporbitalPosition.cross(tmporbitalVelocity)
	var _h=hvec.length()
#	print(hvec)
#	print(h) # ANG MOMENTUM
	
#	var a = (u*r) / ( (2*u) - (r*vel*vel) )
	var specE = ( (vel*vel)/2  ) - ( u/r ) # SPECIFIC ORBIT ENERGY
	var a = -1 * (  u / (2*specE) ) # SEMI MAJOR AXIS
#	print(a)

##Step 3—Inclination
	# i = incliniation
	
##Step 4—Right Ascension of the Ascending Node
	# Omega = longitude of asc node

#Step 5—Eccentricity
	var evec=tmporbitalVelocity.cross(hvec) / u - tmporbitalPosition / r
	var e=evec.length()
#	print(evec)
#	print(e) # ECCENTRICTY
	
#Step 6—Argument of Periapsis       # TODO: fix all this WTF	
#	var w = atan2(evec.y,evec.x)
#	if !orbitCounterClockwise:
#		w = (2*PI)-w
		
	var w = global_position.direction_to(to_global(periAp)).angle()	
	if w < 0:
#		print(w)
		w = (2 * PI) + w
	
#	w = acos(evec.x/ e )
#
#	var K = Vector3(0, 0, 0)
#	var N_vec = K.cross(hvec)
#	var N = N_vec.length()		
#	if N>0:
#		w = acos(N_vec.dot(Vector3.ONE)/N);
#	if evec.z < 0:
#		w = (2 * PI) - acos(N_vec.dot(evec) / (N * e))
#	else:
#		w =            acos(N_vec.dot(evec) / (N * e))
	
#	print(K)
#	print(N_vec)
#	print(N)
#	print(w)
#	print(rad2deg(w)) # ARG OF PERI - even though not really defined at equator - consider periaps as ascending node
#	print()
	
#Step 7—True Anomaly
	var v=0.0
	if velr < 0:
		v = (2 * PI) - acos(evec.dot(tmporbitalPosition) / (e * r))
	else:
		v = acos(evec.dot(tmporbitalPosition) / (e * r)) # TODO: fix all this WTF
	if is_nan(v):
		v=0
#	print(rad2deg(v)) # TRUE ANOM
#	print()
	
	
#FINAL - SET ELEMENTS	
	semiMajorAxis = a
	eccentricty = e
	argPeri = rad2deg(w)
	if v <= PI:
		trueAnomaly = rad2deg(v)
	else:
		trueAnomaly = rad2deg(v-(2*PI))

#	print(semiMajorAxis)
#	print(eccentricty)
#	print(argPeri)
#	print(trueAnomaly)
#	print(180-trueAnomaly)
#	print()
	solveFromTrue()

# ###########################################################################################################

var POINT_COUNT = 60
func _draw():
	draw_arc(Vector2(0,0), orbitalDistance, 0.0, 2.0 * PI, POINT_COUNT, Color.red) # orbit distance	circle			

	draw_set_transform(focus1Pos,0,Vector2.ONE)
	draw_circle(Vector2(0,0),20.0,Color.white) # center
	draw_arc(Vector2(0.0, 0.0), semiMajorAxis, 0.0, 2.0 * PI, POINT_COUNT, Color.darkblue) # ref circle
	
	draw_circle(focus1Pos,20.0,Color.blue) # focus 1
	draw_circle(focus2Pos,20.0,Color.red) # focus 2	
	
	draw_circle(pprime1,10.0,Color.fuchsia) # ref circle p1
	draw_circle(pprime2,10.0,Color.yellow) # ref circle p2
	
	draw_circle(v1,20.0,Color.red) # v1 # apoAp
	draw_circle(v2,20.0,Color.brown) # v2
	draw_circle(v3,20.0,Color.green) # v3 # periAp
	draw_circle(v4,20.0,Color.yellow) # v4
	
	draw_set_transform(focus1Pos,0,Vector2(semiMajorAxis,semiMinorAxis))
	draw_arc(Vector2(0.0, 0.0), 1.0, 0.0, 2.0 * PI, POINT_COUNT, Color.white)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

	draw_line(orbitalPosition,orbitalPosition+orbitalVelocity,Color.green,12.0) # veloc
	
	draw_line(orbitalPosition,orbitalPosition+orbitalVelocityf1,Color.blue,4.0)  
	draw_line(orbitalPosition,orbitalPosition+orbitalVelocityf2,Color.red,4.0)  
	
	draw_line(orbitalPosition,orbitalPosition+orbitalVelocityNormal,Color.white,4.0) # veloc norm
	
#	draw_line(focus1Pos+v3,tmpVector,Color.yellow,25.0)  # TMP VECTOR
#	draw_circle( focus1Pos+v3  ,50.0,Color.white) # TMP CIRCLE
	
	#rotate sprite towards star
	$Sprite.rotation= orbitalVelocityf2.angle() + deg2rad(120)
	
	#position node
	$Sprite.position = orbitalPosition
	$LightOccluder2D.position = orbitalPosition
	
	#rotate to match argPeri
	rotation_degrees=argPeri
	
var localTime=0.0 
func _physics_process(delta):
	if delta>0:
		localTime += delta
		if orbitalDistance>0.0:
			var orbitTime=0
			if orbitalPeriod>0:
				orbitTime = fmod(localTime,orbitalPeriod) # current orbit time from 0 to orbitalPeriod
			epoch = orbitTime		
			
			solveWithTime()
#			solveFromStateVectors() 
			update()
