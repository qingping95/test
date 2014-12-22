#!/bin/bash

#颜色定义
cRed=1
cGreen=2
cYellow=3
cBlue=4
cFuchsia=5
cCyan=6
cWhite=7
colorTable=($cRed $cGreen $cYellow $cBlue $cFuchsia $cCyan $cWhite)

#位置和大小
iLeft=3
iTop=2
((WindowLeft = iLeft + 2))
((WindowTop = iTop + 1))
((WindowWidth = 10))
((WindowHeight = 15))

#颜色设置
cBorder=$cGreen
cScore=$cFuchsia
cScoreValue=$cCyan

#控制信号
#改游戏使用两个进程，一个用于接收输入，一个用于游戏流程和显示界面;
#当前者接收到上下左右等按键时，通过向后者发送signal的方式通知后者。
sigRotate=25
sigLeft=26
sigRight=27
sigDown=28
sigAllDown=29
sigExit=30

#七中不同的方块的定义
#通过旋转，每种方块的显示的样式可能有几种
box0=(0 0 0 1 1 0 1 1)
box1=(0 2 1 2 2 2 3 2 1 0 1 1 1 2 1 3)
box2=(0 0 0 1 1 1 1 2 0 1 1 0 1 1 2 0)
box3=(0 1 0 2 1 0 1 1 0 0 1 0 1 1 2 1)
box4=(0 1 0 2 1 1 2 1 1 0 1 1 1 2 2 2 0 1 1 1 2 0 2 1 0 0 1 0 1 1 1 2)
box5=(0 1 1 1 2 1 2 2 1 0 1 1 1 2 2 0 0 0 0 1 1 1 2 1 0 2 1 0 1 1 1 2)
box6=(0 1 1 1 1 2 2 1 1 0 1 1 1 2 2 1 0 1 1 0 1 1 2 1 0 1 1 0 1 1 1 2)
#所有其中方块的定义都放到box变量中
box=(${box0[@]} ${box1[@]} ${box2[@]} ${box3[@]} ${box4[@]} ${box5[@]} ${box6[@]})
#各种方块旋转后可能的样式数目
countBox=(1 2 2 2 4 4 4)
#各种方块再box数组中的偏移
offsetBox=(0 1 3 5 7 11 15)

#每提高一个速度级需要积累的分数
iScoreEachLevel=10        

#运行时数据
sig=0                #接收到的signal
iScore=0        #总分
iLevel=0        #速度级
boxNew=()        #新下落的方块的位置定义
cBoxNew=0        #新下落的方块的颜色
iBoxNewType=0        #新下落的方块的种类
iBoxNewRotate=0        #新下落的方块的旋转角度
boxCur=()        #当前方块的位置定义
cBoxCur=0        #当前方块的颜色
iBoxCurType=0        #当前方块的种类
iBoxCurRotate=0        #当前方块的旋转角度
boxCurRow=-1         #当前方块的行位置
boxCurColumn=-1        #当前方块的列位置
iMap=()                #背景方块图表

#初始化所有背景方块为-1, 表示没有方块
for ((i = 0; i < WindowHeight * WindowWidth; i++)); do iMap[$i]=-1; done


#接受输入的函数
function ReceiveInput()
{
     local HSID key inputstream sig  cESC  
	   HSID=$1                     #获取HandleSignal进程的ID
	   
	   cESC=`echo -ne "\033"`
	       
           sTTY=`stty -g`              #保存终端属性 
           inputstream=(0 0 0)
           trap "Exitback;" INT TERM   #挂载退出后台的信号
           trap "Exitfront;" $sigExit  #挂在退出前台的信号
           
           #隐藏光标
           echo -ne "\033[?25l"   
	   
           while :
	   do
	   
	           read -s -n 1 key
	   
	           inputstream[0]=${inputstream[1]}     #将输入流依次存入数组中
	           inputstream[1]=${inputstream[2]}
	           inputstream[2]=$key	           
	           sig=0
	   
	           if [[ $key == $cESC && ${inputstream[1]} == $cESC ]]
	              then 
	                   Exitback  
	           elif [[ ${inputstream[0]} == $cESC && ${inputstream[1]} == "[" ]]
	              then 
	                   if [[ $key == "A" ]]; then sig=$sigRotate
		               elif [[ $key == "B" ]]; then sig=$sigDown
		               elif [[ $key == "C" ]]; then sig=$sigRight
		               elif [[ $key == "D" ]]; then sig=$sigLeft 				              
	                   fi
		  fi
				
		  if [[ "[$key]" == "[]" ]]
		  then  
	                 sig=$sigAllDown
	          fi	 
				
	          if [[ $sig != 0 ]]
	          then
	               kill -$sig $HSID
	          fi
       done
}

#绘制新的方块，接受信号并做处理
function HandleSignal()                                                                                            
{
    local localSignal 
	  localSignal=$1
	
	 InitDraw              #绘制新的下落方块
	
	trap "sig=$sigRotate;" $sigRotate     #挂载旋转信号
        trap "sig=$sigLeft;" $sigLeft       #挂载左移一位信号
        trap "sig=$sigRight;" $sigRight      #挂载右移一位信号
        trap "sig=$sigDown;" $sigDown       #挂载下移一位信号
        trap "sig=$sigAllDown;" $sigAllDown    #挂载移到最下面的信号
        trap "ShowGG;" $sigExit       #挂载退出信号
	
	while :
	do
	         for((i=0;i<21-iLevel;i++))
		 do 
		          sleep 0.02
			  localSignal=$sig
			  sig=0
			  
			  if ((localSignal==sigRotate)); then BoxRotate;
			  elif ((localSignal==sigDown)); then BoxDown;
	                  elif ((localSignal==sigLeft)); then BoxLeft;
			  elif ((localSignal==sigRight)); then BoxRight;
			  elif ((localSignal==sigAllDown)); then BoxFall;	  
		          fi
		  done
		  BoxDown                                               
	done     
}

#将下落到底的方块贴到背景中去
function BoxToBackground()                                                                                                         
{
        local i j idx n m line cn cm tmp Time

	for (( i = 0; i < 8; i+=2 ))  #在iMap中将这个地方添加方格
	do
		(( j = i + 1))
		(( n = ${boxCur[$i]} + boxCurRow ))
		(( m = ${boxCur[$j]} + boxCurColumn ))
		(( idx = n * WindowWidth + m ))
		iMap[$idx]=$cBoxCur
	done

	line=0
	
	for (( i = 0; i < WindowHeight; i++ )) #逐行检测有没有可以被消去的行
	do
		for (( j = 0 ; j < WindowWidth ; j++ ))
		do
			(( idx = i * WindowWidth + j ))
			if ((${iMap[$idx]} == -1)); then break; fi
		done

		if (( j != WindowWidth )); then continue; fi #如果没有那么继续检测下一行

		((line++)) # 记录消去了多少行
                
                
                #消去的行闪烁效果
		Time=8
		for((;Time != 0; Time--))
		do
                     	sleep 0.1
			for((j = 0; j < WindowWidth; j++))
			do
				((idx = i * WindowWidth + j))
				((n = WindowTop + i + 1))
				((m = WindowLeft + j * 2 + 1))
				((cn = WindowTop + 7))
				((cm = WindowLeft + WindowWidth * 2 + 5))
				if (( ${iMap[${idx}]} == -1 || Time & 1))
				then				
					echo -ne "\033[${n};${m}H  "
					echo -ne "\033[${cn};${cm}H                  "
				else
					echo -ne "\033[${n};${m}H"
					echo -ne "\033[1m\033[7m\033[3${iMap[$idx]}m\033[4${iMap[$idx]}m[]\033[0m"
					if (( line == 2 ))
					then
						echo -ne "\033[32m\033[${cn};${cm}HGood!"
					elif (( line == 3 ))
					then
						echo -ne "\033[34m\033[${cn};${cm}HPrefect!!"
					elif (( line == 4 ))
					then
						echo -ne "\033[32m\033[${cn};${cm}HAmazing!!!"
					fi
				fi
			done
		done


		for (( cn = i - 1; cn >= 0; cn--))
		do
			for(( cm=0; cm < WindowWidth; cm++))
			do
				((idx = cn * WindowWidth +cm))
				((tmp = idx + WindowWidth))
				iMap[$tmp]=${iMap[$idx]}
			done
		done
		for (( idx = 0; idx < WindowWidth; idx++))
		do
			iMap[$idx]=-1
		done
	done
        
	if ((line == 0)); then return; fi

	#显示新的分数和等级
	((n = iTop + 12))
	((m = iLeft + WindowWidth * 2 + 7))
	((iScore += line * 2 - 1))

	echo -ne "\033[1m\033[3${cScoreValue}m\033[${n};${m}H${iScore}"

	if (( iScore / iScoreEachLevel > iLevel ))
	then
		if((iLevel < 20))
		then
			(( iLevel++ ))
			(( n = iTop + 15))
			echo -ne "\033[1m\033[3${cScoreValue}m\033[${n};${m}H${iLevel}"
		fi
	fi
	echo -ne "\033[0m"

	#上述操作处理完之后，重新绘制背景
	for ((i=0; i < WindowHeight; i++))
	do
		for ((j=0; j < WindowWidth; j++))
		do
			((idx = i * WindowWidth +j))
			((n = WindowTop + i + 1))
			((m = WindowLeft + j * 2 + 1))
			if (( ${iMap[${idx}]} == -1))
			then				
				echo -ne "\033[${n};${m}H  "
			else
				echo -ne "\033[${n};${m}H"
				echo -ne "\033[1m\033[7m\033[3${iMap[$idx]}m\033[4${iMap[$idx]}m[]\033[0m"
			fi
		done
	done
}

#随机产生新的方块
function RandomBox()
{
	local i j tmp cn cm

	iBoxCurType=${iBoxNewType}
	iBoxCurRotate=${iBoxNewRotate}
	cBoxCur=${cBoxNew}

	
	for((i=0; i < ${#boxNew[@]}; i++))
	do
		boxCur[$i]=${boxNew[$i]}
	done

	#计算boxCurColumn,boxCurRow
	if((${#boxCur[@]==8}))
	then
		for ((i=0,t=4; i<8; i+=2))
		do
			if((boxCur[$i]<t)); then t=${boxCur[$i]}; fi
		done
		((boxCurRow = -t))
		for ((i=1 , t=4 , j=0; i<8; i+=2))
		do
			if((boxCur[$i]<t)); then t=${boxCur[$i]}; fi
			if((boxCur[$i]>j)); then j=${boxCur[$i]}; fi
		done
		((boxCurColumn = (WindowWidth - j - t) / 2))

		echo -ne `DrawCurBox 1`

		if ! BoxMove $boxCurRow $boxCurColumn
		then 
			kill -$sigExit ${PPID}  #发送信号给ReceiveInput
		        ShowGG
		fi
	fi

	#清除
	for((i = 0; i<4; i++))
	do
		((cn = iTop + 1 + i))
		((cm = iLeft + 2 * WindowWidth + 7))
		echo -ne "\033[${cn};${cm}H           "
	done

	#产生下一个方块
	((iBoxNewType = RANDOM % ${#offsetBox[@]}))
	((iBoxNewRotate = RANDOM % ${#countBox[$iBoxNewType]}))
	((cBoxNew = RANDOM % 7 + 1))
	for((i=0; i<8; i++))
	do
		((tmp = (${offsetBox[$iBoxNewType]}+$iBoxNewRotate) * 8 +i))
		boxNew[$i]=${box[$tmp]}
	done


	#将新的方块放到右边
	for ((i = 0; i < 8; i += 2))
	do
		((j = i + 1))
		((cn = iTop + 1 + ${boxNew[$i]}))
		((cm = iLeft + 2 * ( WindowWidth + ${boxNew[$j]} ) + 7 ))
		echo -ne "\033[1m\033[7m\033[3${cBoxNew}m\033[4${cBoxNew}m\033[${cn};${cm}H[]"
	done

	echo -ne "\033[0m"
}

#检测方块是否可以移动到指定的位置
function BoxMove()
{
	local j i x y xTest yTest
	yTest=$1
	xTest=$2
	for (( j = 0;j < 8;j += 2 ))
	do
		(( i = j + 1 ))
		(( y = ${boxCur[$j]}+yTest ))
		(( x = ${boxCur[$i]}+xTest ))
		if (( y < 0 || y >= WindowHeight || x < 0 || x >= WindowWidth))
			then
				return 1
		fi
		if((${iMap[y * WindowWidth+x]} != -1))
			then
				return 1
		fi
	done
	return 0;
}


#绘制当前方块
function DrawCurBox()
{
        local i j t bDraw sBox s
        bDraw=$1

        s=""
        if (( bDraw == 0 ))
        then
                sBox="\040\040"
        else
                sBox="[]"
                s=$s"\033[1m\033[7m\033[3${cBoxCur}m\033[4${cBoxCur}m"
        fi

        for ((j = 0; j < 8; j += 2))
        do
                ((i = WindowTop + 1 + ${boxCur[$j]} + boxCurRow))
                ((t = WindowLeft + 1 + 2 * (boxCurColumn + ${boxCur[$j + 1]})))
                #\033[y;xH, 光标到(x, y)处
                s=$s"\033[${i};${t}H${sBox}"
        done
        s=$s"\033[0m"
        echo -n $s
}

#方块向左移动一格
function BoxLeft()
{
        local x s
        ((x = boxCurColumn - 1))
        if BoxMove $boxCurRow $x
        then
                s=$(DrawCurBox 0)
                ((boxCurColumn=x))
                s=$s$(DrawCurBox 1)
                echo -ne $s
        fi
}

#方块向右移动一格
function BoxRight()
{
    local s
    if BoxMove $boxCurRow $((boxCurColumn+1))
        then
            s=$(DrawCurBox 0)
            ((++boxCurColumn))
			s=$s$(DrawCurBox 1)
			echo -ne $s
    fi
}

#方块下落一格
function BoxDown()
{
	local s
	if BoxMove $((boxCurRow+1)) $boxCurColumn	#if Down is available
		then 
			s=$(DrawCurBox 0)
			((++boxCurRow))
			s=$s$(DrawCurBox 1)
			echo -ne $s
	else
			BoxToBackground
			RandomBox
	fi
}

#方块下落到底
function BoxFall()
{
	local k j i x y rDown s
    rDown=$WindowHeight

    #计算一共需要下落多少行
    for ((j = 0; j < 8; j += 2))
    do
        ((i = j + 1))
        ((y = ${boxCur[$j]} + boxCurRow))
        ((x = ${boxCur[$i]} + boxCurColumn))
        for ((k = y + 1; k < WindowHeight; k++))
        do
                ((i = k * WindowWidth + x))
                if (( ${iMap[$i]} != -1)); then break; fi
        done
        ((k -= y + 1))
        if (( $rDown > $k )); then rDown=$k; fi
    done

    s=$(DrawCurBox 0)
    ((boxCurRow += rDown))
	s=$s$(DrawCurBox 1)
	echo -ne $s
    BoxToBackground          #将当前移动中的方块贴到背景方块中
    RandomBox        #产生新的方块
}

#绘制新的方块
function InitDraw()
{
	clear
	RandomBox
	RandomBox		#put the box to the right sidebar

	local i t1 t2 t3

	echo -ne "\033[1m"
	echo -ne "\033[3${cBorder}m\033[4${cBorder}m"

	(( t2 =  iLeft + 1 ))
	(( t3 =  iLeft + WindowWidth*2 + 3))	
	for ((i = 0; i < WindowHeight; i++))
	do
		(( t1 = i + iTop + 2 ))
		echo -ne "\033[${t1};${t2}H||"
		echo -ne "\033[${t1};${t3}H||"
	done

	(( t2 = iTop + WindowHeight + 2))
	for ((i = 0; i < WindowWidth+2; i++))
	do
		(( t1 = i*2 + iLeft + 1 ))
		echo -ne "\033[${WindowTop};${t1}H=="
		echo -ne "\033[${t2};${t1}H=="
	done
	echo -ne "\033[0m"
    
	echo -ne "\033[1m"
	(( t1 = iLeft + WindowWidth * 2 + 7 ))
	(( t2 = iTop + 11))
	echo -ne "\033[3${cScore}m\033[${t2};${t1}HScore"
	(( t2 = iTop + 12))
	echo -ne "\033[3${cScoreValue}m\033[${t2};${t1}H${iScore}"
	(( t2 = iTop + 14))
	echo -ne "\033[3${cScore}m\033[${t2};${t1}HLevel"
	(( t2 = iTop + 15))
	echo -ne "\033[3${cScoreValue}m\033[${t2};${t1}H${iLevel}"
	echo -ne "\033[0m"
}

#方块旋转
function BoxRotate()
{
	local iCount iTestRotate boxTest j i s
	iCount=${countBox[$iBoxCurType]}

	(( iTestRotate = iBoxCurRotate + 1))
	if ((iTestRotate >= iCount))
		then
			((iTestRotate = 0))
	fi

	for ((j=0, i = (${offsetBox[$iBoxCurType]} + $iTestRotate) *8; j < 8; j++,i++))
	do
		boxTest[$j]=${boxCur[$j]}
		boxCur[$j]=${box[$i]}
	done

	if BoxMove $boxCurRow $boxCurColumn
		then
			for ((j = 0; j < 8; j++))
			do
				boxCur[$j]=${boxTest[$j]}
			done
			s=$(DrawCurBox 0)

			for ((j = 0, i = (${offsetBox[$iBoxCurType]} + $iTestRotate) *8; j < 8; j++,i++))
			do
				boxCur[$j]=${box[$i]}
			done
			s=$s$(DrawCurBox 1)
			echo -ne $s
			iBoxCurRotate=$iTestRotate
	else
		for ((j = 0; j < 8; j++))
		do
			boxCur[$j]=${boxTest[$j]}
		done
	fi
}

#退出前台进程
function Exitfront()
{
        local y

        #恢复终端属性
        stty $sTTY
        ((y = iTop + WindowHeight + 4))

        #显示光标
        echo -e "\033[?25h\033[${y};0H"
        exit

}

#退出后台进程
function Exitback()                                                                                                   
{
     kill -$sigExit $HSID
     Exitfront  
}

#显示gameover
function ShowGG()                                                                                                           
{
        local y
        ((y = WindowHeight + WindowTop + 3))
        echo -e "\033[${y};0HGameOver!\033[0m"
        exit
}

#程序开始
if [[ "$1" == "--show" ]] 
then
        HandleSignal
else
        bash $0 --show&        
        ReceiveInput $!        
fi


