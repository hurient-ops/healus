**HealUs Project**

**ver 1.00**

**D.H.Kim**

# Preface

이 문서는 모바일 앱과 인슐린펌프 사이에 BLE를 이용해서 통신하는 메시지들을 정의한다.

# Introduction

1.  정의된 메시지들은 BLE를 이용해 전달된다.

2.  메시지정의는 implementation-specific이다.

# Message Basic Structure

## **Description**

1.  이 장은 모든 메시지에서 사용되는 구조를 정의한다.

##  **Structure**

| 0번째 | 1번째 | 2번째 |  3번째~19번째  |
|:-----:|:-----:|:-----:|:--------------:|
| 1byte | 1byte | 1byte | 0byte ~ 17byte |

1.  메시지 길이는 20byte 고정이다.

2.  0번째 바이트는 Start code이고, 값은 0xEF 이다.

3.  1번째 바이트는 type code이고, 이 바이트는 메시지 타입을 나타낸다.

4.  2번째 바이트는 데이터 길이이고, 이 바이트는 현재 메시지의 데이터 길이를 나타낸다. 만일 길이가 0이면, 데이터는 없는 것이다.

5.  3번째 바이트부터는 데이터다. 사용되는 데이터는 메시지 타입마다 다르다. 데이터는 설명되는 순서대로 2번째 데이터부터 위치한다.

6.  **20byte 메시지는 10byte씩 2번 수신하거나, 10byte씩 2번 송신한다.**

7.  **송신시 10byte를 2번 분리해서 전송하고, 수신시 10byte를 2번 받아 재조립 한다.**

    - **10byte 분할 송신 및 수신 재조립 로직 구현**

    - **<u>0xEF</u>로 시작하는 20byte 길이의 완전한 메시지(헤더, 데이터)를 구성한다.**

    - **메시지의 첫 10byte를 추출하여 전송한다.**

    - **수신 버퍼 처리 및 인터럽트 처리 시간을 고려하여, 약 50ms ~ 100ms 정도의 지연 시간을 둔다.**

    - **메시지의 다음 10byte를 추출하여 전송한다.**

### **Data Location (메시지 데이터 위치)**

1.  일반 hexa-decimal 값들은 **little-endian 방식**이 사용된다. 즉 0x000102, 0x0304, 0x05값을 대입할 경우 아래와 같이 적용된다.

| 0번째 |    1번째     |    2번째    | 3번째 | 4번째 | 5번째 | 6번째 | 7번째 | 8번째 | 9번쨰~ |
|:-----:|:------------:|:-----------:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:------:|
| 0xEF  | Message Type | Data Length | 0x02  | 0x01  | 0x00  | 0x04  | 0x03  | 0x05  |   …    |

2.  ASCII code들은 읽혀지는 순서와 같다. 즉 “1234” 같은 값을 대입할 경우 아래와 같이 적용된다.

| 0번째 |    1번째     |    2번째    | 3번째 | 4번째 | 5번째 | 6번째 | 7번째 ~ |
|:-----:|:------------:|:-----------:|:-----:|:-----:|:-----:|:-----:|:-------:|
| 0xEF  | Message Type | Data Length |  ‘1’  |  ‘2’  |  ‘3’  |  ‘4’  |         |

# Message Classification

## **Description**

1.  메시지는 세 종류로 분리된다. Request 또는 Command 메시지, 이에 응답하는 Response 메시지, 그리고 요청없이 바로 전달하는 Indication 메시지.

2.  Request 또는 Command 메시지는 상대방에게 어떤 요청을 할 때 사용되고, 요청에 대한 처리 가능 여부를 Response 메시지로 응답한다.

3.  상대방에게 긴급한 정보나 오류를 바로 알려 할 경우에는 Indication 메시지를 사용한다.

## **Message Sequence Flow**

1.  요청과 응답 Flow

- 앱 -\>\> 인슐린펌프: Request 메시지 전송

- 앱 \<\<- 인슐린펌프: Response 메시지 전송

2.  알림 Flow

    - 앱 \<\<- 인슐린펌프: Indication 메시지 전송

# Message Types

## **Description**

1.  사용되는 메시지 종류를 정의한다.

## **Message Types**

<table>
<colgroup>
<col style="width: 16%" />
<col style="width: 27%" />
<col style="width: 8%" />
<col style="width: 47%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;"><strong>Category</strong></th>
<th style="text-align: center;"><strong>Message Type</strong></th>
<th style="text-align: center;"><strong>Value</strong></th>
<th style="text-align: center;"><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;">요청 응답</td>
<td style="text-align: left;">BT_MSG_RES</td>
<td style="text-align: center;">0x00</td>
<td style="text-align: left;">요청에 대한 응답</td>
</tr>
<tr>
<td rowspan="3" style="text-align: left;">장치 시작/초기화</td>
<td style="text-align: left;">BT_START_REQ</td>
<td style="text-align: center;">0x01</td>
<td style="text-align: left;">상호 BLE통신을 시작하도록 요청 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_CONNECTABLE_CTRL_REQ</td>
<td style="text-align: center;">0x02</td>
<td style="text-align: left;">상호 BLE통신을 시작하도록 요청 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_SYSEM_RESET</td>
<td style="text-align: center;">0x43</td>
<td style="text-align: left;">시스템 Reset (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td rowspan="2" style="text-align: left;">장치 상태</td>
<td style="text-align: left;">BT_STATE_REQ</td>
<td style="text-align: center;">0x04</td>
<td style="text-align: left;">장치의 현재 상태를 요청한다. (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_STATE_IND</td>
<td style="text-align: center;">0x05</td>
<td style="text-align: left;">장치의 현재 상태를 알린다. (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td rowspan="9" style="text-align: left;">기기 정보</td>
<td style="text-align: left;">BT_CUR_TIME_IND</td>
<td style="text-align: center;">0x06</td>
<td style="text-align: left;">현재 시간 정보를 알린다. (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_CUR_TIME_RES</td>
<td style="text-align: center;">0x44</td>
<td style="text-align: left;">앱으로부터 받은 시간을 앱에게 확인 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_BATT_DATA_REQ</td>
<td style="text-align: center;">0x70</td>
<td style="text-align: left;">배터리 잔량요청 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_BATT_DATA_RES</td>
<td style="text-align: center;">0x72</td>
<td style="text-align: left;">배터리 잔량응답 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_BATT_DATA_IND</td>
<td style="text-align: center;">0x71</td>
<td style="text-align: left;"><p>배터리 잔량응답 (00, 01, 02, 03, 04 5단계표시)</p>
<p>00: Empty, 04: Full (인슐린펌프 -&gt; 앱)</p></td>
</tr>
<tr>
<td style="text-align: left;">BT_PUMP_PID_REQ</td>
<td style="text-align: center;">0x09</td>
<td style="text-align: left;">펌프의 고유의 PID 요청 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_PUMP_PID_RES</td>
<td style="text-align: center;">0x0A</td>
<td style="text-align: left;">펌프의 고유의 PID 값을 알린다. (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_PUMP_FW_REQ</td>
<td style="text-align: center;">0x3E</td>
<td style="text-align: left;">펌프 FW ver 요청 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_PUMP_FW_RES</td>
<td style="text-align: center;">0x3F</td>
<td style="text-align: left;">펌프 FW ver 전송 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td rowspan="4" style="text-align: left;">대량 데이터</td>
<td style="text-align: left;">BT_LOG_REQ</td>
<td style="text-align: center;">0x1D</td>
<td style="text-align: left;">이력데이터 요청 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_DATA_START_IND</td>
<td style="text-align: center;">0x0B</td>
<td style="text-align: left;"><p>대량 패킷 시작 알림 (인슐린펌프 -&gt; 앱)</p>
<p>주입 이력데이터 시작 알림 (15일 기준)</p></td>
</tr>
<tr>
<td style="text-align: left;">대량 패킷 데이터</td>
<td style="text-align: center;">없음</td>
<td style="text-align: left;">BT_DATA_START_IND 이후 시작하여 BT_DATA_END_IND까지 전송되는 대량 데이터 (15일 기준)</td>
</tr>
<tr>
<td style="text-align: left;">BT_DATA_END_IND</td>
<td style="text-align: center;">0x0C</td>
<td style="text-align: left;"><p>다량 패킷 종료 알림 (인슐린펌프 -&gt; 앱)</p>
<p>주입 이력데이터 종료 알림</p></td>
</tr>
<tr>
<td style="text-align: left;">일시 정지</td>
<td style="text-align: left;">BT_STOP_CTRL_REQ</td>
<td style="text-align: center;">0x0D</td>
<td style="text-align: left;">기기를 잠시 정지한다. (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td rowspan="3" style="text-align: left;">설정</td>
<td style="text-align: left;">BT_TIME_BASE_SET_REQ</td>
<td style="text-align: center;">0x0F</td>
<td style="text-align: left;">시간별 기초 설정 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_MEAL_SET_REQ</td>
<td style="text-align: center;">0x10</td>
<td style="text-align: left;">식사 설정 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_SET_RES</td>
<td style="text-align: center;">0x12</td>
<td style="text-align: left;">설정 요청에 따른 응답 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td rowspan="12" style="text-align: left;">주입</td>
<td style="text-align: left;">BT_EXERCISE_SET_REQ</td>
<td style="text-align: center;">0x13</td>
<td style="text-align: left;">운동모드 설정 및 주입 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_EXERCISE_INJ_START_IND</td>
<td style="text-align: center;">0x29</td>
<td style="text-align: left;">운동모드시작 알림 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_EXERCISE_INJ_STOP_IND</td>
<td style="text-align: center;">0x2A</td>
<td style="text-align: left;">운동모드 종료 알림 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_RECEPTION_SET_REQ</td>
<td style="text-align: center;">0x14</td>
<td style="text-align: left;">회식모드 설정 및 주입 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_RECEPTION_INJ_START_IND</td>
<td style="text-align: center;">0x2B</td>
<td style="text-align: left;">회식모드 시작 알림 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_RECEPTION_INJ_STOP_IND</td>
<td style="text-align: center;">0x2C</td>
<td style="text-align: left;">회식모드 종료 알림 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;"><strong>BT_INJ_INFO_REQ</strong></td>
<td style="text-align: center;">0x15</td>
<td style="text-align: left;">주입 정보 요청 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;"><strong>BT_INJ_INFO_RES</strong></td>
<td style="text-align: center;">0x16</td>
<td style="text-align: left;">주입 정보 응답 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_INJ_REQ</td>
<td style="text-align: center;">0x17</td>
<td style="text-align: left;">주입 요청 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_INJ_START_IND</td>
<td style="text-align: center;">0x3A</td>
<td style="text-align: left;">주입시작 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_INJ_STOP_IND</td>
<td style="text-align: center;">0x3B</td>
<td style="text-align: left;">주입완료 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_INJ_STOP_REQ</td>
<td style="text-align: center;">0x37</td>
<td style="text-align: left;">주입 중 강제정지 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">오류 상태 알림</td>
<td style="text-align: left;">BT_ERR_IND</td>
<td style="text-align: center;">0x19</td>
<td style="text-align: left;">장치에 오류 상태가 되면 알림 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td rowspan="2" style="text-align: left;">이력 데이터 처리</td>
<td style="text-align: left;">BT_LOG_INJ_QNT_REQ</td>
<td style="text-align: center;">0x1E</td>
<td style="text-align: left;">금일 주입량 정보 요청 (Only 금일기준) (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_LOG_INJ_QNT_IND</td>
<td style="text-align: center;">0x1F</td>
<td style="text-align: left;">금일 주입량 정보 응답 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td rowspan="4" style="text-align: left;">설정정보 확인</td>
<td style="text-align: left;">BT_EAT_VALUE_REQ</td>
<td style="text-align: center;">0x2D</td>
<td style="text-align: left;">펌프의 식사 설정 값을 요청한다. (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_EAT_VALUE_RES</td>
<td style="text-align: center;">0x2E</td>
<td style="text-align: left;">펌프의 식사 설정 값을 전달한다. (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_BASE_VALUE_REQ</td>
<td style="text-align: center;">0x2F</td>
<td style="text-align: left;">펌프의 기초 설정 값을 요청한다. (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_BASE_VALUE_RES</td>
<td style="text-align: center;">0x30</td>
<td style="text-align: left;"><p>펌프의 기초 설정 값을 전달한다. (인슐린펌프 -&gt; 앱)</p>
<p>(순차적으로 3번(3(회)*8(H))) 전송</p></td>
</tr>
<tr>
<td rowspan="2" style="text-align: left;">설정 통보</td>
<td style="text-align: left;">BT_BASE_VALUE_IND</td>
<td style="text-align: center;">0x40</td>
<td style="text-align: left;"><p>기초 설정 값 변경 시 전달 (인슐린펌프 -&gt; 앱)</p>
<p>(순차적으로 3번(3(회)*8(H))) 전송</p></td>
</tr>
<tr>
<td style="text-align: left;">BT_LOG_INJ_SET_1_IND</td>
<td style="text-align: center;">0x20</td>
<td style="text-align: left;">현 주입 설정이력 정보1 (아침, 점심, 저녁 설정 이력 정보) -&gt; 인슐린펌프에서 아침/점심/저녁 식사주입 변경시 앱으로 자동 통보하는 기능</td>
</tr>
<tr>
<td rowspan="4" style="text-align: left;"><p>APP</p>
<p>Password변경</p></td>
<td style="text-align: left;">BT_PRS_APP_PASSWD_IND</td>
<td style="text-align: center;">0x3C</td>
<td style="text-align: left;">기존 Password정보 전달 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_NEW_APP_PASSWD_IND</td>
<td style="text-align: center;">0x3D</td>
<td style="text-align: left;">신규 Password정보 전달 (인슐린펌프 -&gt; 앱)</td>
</tr>
<tr>
<td style="text-align: left;">BT_PRS_APP_PASSWD_REQ</td>
<td style="text-align: center;">0x41</td>
<td style="text-align: left;">현재 앱 PassWord 조회 요청 (앱 -&gt; 인슐린펌프)</td>
</tr>
<tr>
<td style="text-align: left;">BT_PRS_APP_PASSWD_RES</td>
<td style="text-align: center;">0x42</td>
<td style="text-align: left;">현재 PassWord 전달 (인슐린펌프 -&gt; 앱)</td>
</tr>
</tbody>
</table>

# Data Types

## **Description**

1.  사용되는 데이터 타입을 정의한다.

## **Message Types**

1.  BOOL type

- Boolean type을 정의한다.

- Data type length: 1 byte

- Data value

| **BOOL Type** | **Value** | **Description** |
|---------------|-----------|-----------------|
| FALSE         | 0         | Boolean의 false |
| TRUE          | 1         | Boolean의 true  |

2.  RES_CODE type.

- 요청에 대한 응답 코드 code.

- Data value

| **RES_CODE type**      | **Value** | **Description**                   |
|------------------------|-----------|-----------------------------------|
| RES_OK                 | 0x00      | 요청 처리 가능                    |
| RES_INVALID_STATUS     | 0x01      | 현재 상태에서 요청 처리 불가      |
| RES_INVALID_PARAM      | 0x02      | 요청의 메시지 매개변수가 잘 못 됨 |
| RES_UNKNOWN_MSG        | 0x03      | 정의되지 않은 Message type        |
| RES_CAN_NOT_HANDLE_MSG | 0x04      | 기타 이유로 요청 처리 불가        |

3.  DATE type

- Boolean type을 정의한다.

- Data type length: 6 bytes

- Data value

| **DATE Type Field** | **Length (byte)** | **Description**  |
|---------------------|-------------------|------------------|
| YEAR                | 1                 | 년도를 나타낸다. |
| MONTH               | 1                 | 달을 나타낸다.   |
| DAY                 | 1                 | 일자를 나타낸다. |
| HOUR                | 1                 | 시간을 나타낸다. |
| MIN                 | 1                 | 분을 나타낸다.   |
| SEC                 | 1                 | 초를 나타낸다.   |

# 요청에 대한 응답

## **Description**

1.  Request 메시지에 대한 응답 메시지

## **Message Sequence Flow**

1.  응답 메시지 Flow

- 앱 -\>\> 인슐린펌프: 특정 Request 메시지 전송

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송

## **Message Types**

1.  BT_MSG_RES(0x00)

- Handshaking을 위한 Request 메시지에 대한 응답.

- 이 후부터는 BT_MSG_RES에 대한 설명은 생략된다.

- Data length: 2

- Data

  - 3번재 msg_type : 1byte. 요청된 메시지의 Message Type code

  - 4번째 res_code : 1byte. Response code.(00 : 정상, 01: 비정상(invalid)), BT_STATE_REQ(0x04) 패킷의 응답에 대해서만 현재상태(cur_state) 값을 응답한다.

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 9%" />
<col style="width: 9%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td style="text-align: center;"><strong>mag_type</strong></td>
<td style="text-align: center;"><strong>res_code</strong></td>
<td colspan="15" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

# 장치 시작 및 초기화 (수정)

## **Description**

1.  장치 시작을 위한 초기화를 수행하고 동작을 시작하도록 요청한다.

## **Message Sequence Flow**

1.  BLE 통신을 통한 장치 시작 Flow

- 앱 \<\<- 인슐린펌프: BT_START_REQ 메시지 전송 (BLE통신 시작 요청)

- 앱 -\>\> 인슐린펌프: BT_CONNECTABLE_CTRL_REQ 메시지 전송 (BLE통신 시작 요청)

## **Message Types**

1.  BT_START_REQ(0x01) (인슐린펌프 -\> 앱)

- 장치에서 앱으로 BLE통신을 시작하도록 요청

- msg_type: 0x01

- Data length: 0

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

2.  BT_CONNECTABLE_CTRL_REQ(0x02) (앱 -\> 인슐린펌프)

- 앱에서 장치로 BLE통신을 시작하도록 요청 (앱 -\> 인슐린펌프)

- msg_type: 0x02

- Data length: 0

> **\* 본 메시지는 매우 중요하기에 RES가 오지 않을 경우 추가 REQ 시도 필요!**

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>02</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

3.  BT_SYSEM_RESET(0x43) (앱 -\> 인슐린펌프)

- BT_STATE_REQ에서 BT_STATE_IND 값이 IDLE상태확인 필요

- Idle상태확인이 안될 경우, BT_STATE_REQ를 재전송하여 2차 Idle상태 확인시에도 Idle상태가 아니면 Reset시도

- msg_type: 0x43

- Data length: 0

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>43</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

# 장치 상태

## **Description**

1.  장치 현재 상태를 요청하고 알린다.

## **Message Sequence Flow**

1.  상태 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_STATE_REQ 메시지 전송 (장치 상태 값 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (res_code에 장치 상태 값 응답)

2.  상태 알림 Flow

- 앱 \<\<- 인슐린펌프: BT_STATE_IND 메시지 전송 (상태가 변경될 때 알림)

## **Message Types**

1.  BT_STATE_REQ(0x04) (앱 -\> 인슐린펌프)

- 장치의 현재 상태를 요청한다.

- msg_type: 0x04

- Data length: 0

- BT_MSG_RES로 응답 (4번째 res_code는 아래 BT_STATE_IND(0x05) 메시지의 현재 상태 (cur_state) 적용)

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>04</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 응답 데이터

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 7%" />
<col style="width: 11%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td style="text-align: center;"><strong>02</strong></td>
<td style="text-align: center;"><strong>Msg_ Type</strong></td>
<td style="text-align: center;"><strong>현재상태 (cur_state)</strong></td>
<td colspan="15" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- (인슐린펌프 -\> 앱) -\> 일시 정지 상태 예시

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **00** | **02** | **04** | **03** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

2.  BT_STATE_IND(0x05) (인슐린펌프 -\> 앱)

- 현재 상태의 요청을 받거나, 상태가 변경될 때마다 상태를 알린다.

- msg_type: 0x05

- Data length: 1

- Data

  - cur_state: 1 byte. 현재 상태

| Current State     | **Value** | **Description** |
|-------------------|-----------|-----------------|
| state_unknown     | 0x00      | 알 수 없는 상태 |
| state_idle        | 0x01      | 동작 대기       |
| state_inj         | 0x02      | 주입 중         |
| state_normal_stop | 0x03      | 일시 정지       |
| state_replace     | 0x04      | 교체 중         |
| state_error_pause | 0x05      | 오류 정지       |

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 16%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>05</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td style="text-align: center;"><strong>현재상태 (cur_state)</strong></td>
<td colspan="16" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(오류 정지 상태)

|   0    |   1    |   2    |   3    |  4  |  5  |  6  |  7  |  8  |  9  | 10  | 11  | 12  | 13  | 14  | 15  | 16  | 17  | 18  | 19  |
|:------:|:------:|:------:|:------:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **EF** | **05** | **01** | **05** | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  |

# 기기 정보

## **Description**

1.  장치에 필요한 정보들을 처리한다.

## **Message Sequence Flow**

1.  시간동기화 Flow

- 앱 -\>\> 인슐린펌프: BT_CUR_TIME_IND 메시지 전송 (현재 시간 동기화)

- 앱 \<\<- 인슐린펌프: BT_CUR_TIME_RES 메시지 전송 (현재 시간 동기화)

2.  배터리 잔량정보 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_BATT_DATA_REQ 메시지 전송 (배터리 잔량정보 요청)

- 앱 \<\<- 인슐린펌프: BT_BATT_DATA_RES 메시지 전송 (배터리 잔량정보 응답)

- 앱 \<\<- 인슐린펌프: BT_BATT_DATA_IND (배터리 level변화시 자동 전송)

3.  PID 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_PUMP_PID_REQ 메시지 전송 (인슐린펌프 PID 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

- 앱 \<\<- 인슐린펌프: BT_PUMP_PID_RES 메시지 전송 (인슐린펌프 PID 응답)

4.  Firmware version 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프 : BT_PUMP_FW_REQ 메시지 전송 (Firmware version 요청)

- 앱 \<\<- 인슐린펌프 : BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

- 앱 \<\<- 인슐린펌프 : BT_PUMP_FW_RES 메시지 전송 (Firmware version 응답)

## **Message Types**

1.  BT_CUR_TIME_IND(0x06) (앱 -\> 인슐린펌프)

- 현재 시간을 알린다.

- msg_type: 0x06

- Data length: 6.

- Data

  - cur_time: 6byte. DATE type. 현재 시간(년/월/일/시/분/초)

- **Packet Structure**

<table>
<colgroup>
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td><strong>년</strong></td>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="11" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제 (2026년 06월 01일 10시 30분 50초)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **06** | **06** | **1A** | **06** | **01** | **0A** | **1E** | **32** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

2.  BT_CUR_TIME_RES(0x44) (인슐린펌프 -\> 앱)

- 인슐린펌프가 앱으로부터 받은 시간을 앱에게 확인

- msg_type: 0x44

- Data length: 6.

- Data

  - cur_time: 6byte. DATE type. 현재 시간(년/월/일/시/분/초)

- **Packet Structure**

<table>
<colgroup>
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>44</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td><strong>년</strong></td>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="11" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제 (2026년 06월 01일 10시 30분 50초)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **44** | **06** | **1A** | **06** | **01** | **0A** | **1E** | **32** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

3.  BT_BATT_DATA_REQ(0x70) (앱 -\> 인슐린펌프)

- 배터리 잔량을 요청한다.

- msg_type: 0x70

- Data length: 0

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>70</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

4.  BT_BATT_DATA_RES(0x72) (인슐린펌프 -\> 앱)

- 배터리 잔량정보를 응답한다. (00: Empty, 01~03: Normal, 04: Full)

- msg_type: 0x72

- Data length: 1

- Data

  - batt_level: 1 byte. 현재 배터리 수준.

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 15%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>72</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td style="text-align: center;"><strong>배터리 잔량</strong></td>
<td colspan="16" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(배터리 Full)

|   0    |   1    |   2    |   3    |  4  |  5  |  6  |  7  |  8  |  9  | 10  | 11  | 12  | 13  | 14  | 15  | 16  | 17  | 18  | 19  |
|:------:|:------:|:------:|:------:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **EF** | **72** | **01** | **04** | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  |

5.  BT_BATT_DATA_IND(0x71) (인슐린펌프 -\> 앱)

- 배터리 잔량응답 (00: Empty, 01~03: Normal, 04: Full)

- msg_type: 0x71

- Data length: 1

- Data

  - batt_level: 1 byte. 현재 배터리 수준.

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 15%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>71</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td style="text-align: center;"><strong>배터리 잔량</strong></td>
<td colspan="16" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(배터리 Empty)

|   0    |   1    |   2    |   3    |  4  |  5  |  6  |  7  |  8  |  9  | 10  | 11  | 12  | 13  | 14  | 15  | 16  | 17  | 18  | 19  |
|:------:|:------:|:------:|:------:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **EF** | **72** | **01** | **00** | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  |

6.  BT_PUMP_PID_REQ(0x09) (앱 -\> 인슐린펌프)

- 펌프 기기의 PID를 요청한다.

- msg_type: 0x09

- Data length: 0

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>09</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

7.  BT_PUMP_PID_RES(0x0A) (인슐린펌프 -\> 앱)

- 펌프 기기의 PID 요청에 대한 응답

- msg_type: 0x0A

- Data length: 4.

- Data

  - pump_pid: 4 bytes. 펌프의 PID를 전달한다.

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0A</strong></td>
<td style="text-align: center;"><strong>04</strong></td>
<td style="text-align: center;"><strong>첫번째 PID</strong></td>
<td style="text-align: center;"><strong>두번째 PID</strong></td>
<td style="text-align: center;"><strong>세번째 PID</strong></td>
<td style="text-align: center;"><strong>네번째 PID</strong></td>
<td colspan="13" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(PID값 AABBCCDD)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **0A** | **04** | **AA** | **BB** | **CC** | **DD** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

8.  BT_PUMP_FW_REQ(0x3E) (앱 -\> 인슐린펌프)

- 펌프 기기의 F/W Version을 요청한다.

- msg_type: 0x3E

- Data length: 0

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>3E</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

9.  BT_PUMP_FW_RES(0x3F) (인슐린펌프 -\> 앱)

- 펌프 기기의 F/W Version을 전송한다.

- msg_type: 0x3F

- Data length: 2

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 9%" />
<col style="width: 9%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>3F</strong></td>
<td style="text-align: center;"><strong>02</strong></td>
<td style="text-align: center;"><strong>정수 부분</strong></td>
<td style="text-align: center;"><strong>소수점 이하 부분</strong></td>
<td colspan="15" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(F/W 버전 1.5)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **3F** | **02** | **01** | **05** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

# 대량 데이터

## **Description**

1.  다수의 데이터를 전송할 때 패킷들을 제어하는데 사용된다.

## **Message Sequence Flow**

1.  대량 기록 데이터 요청 및 전송 Flow

- 앱 -\>\> 인슐린펌프: BT_LOG_REQ 메시지 전송 (인슐린펌프에 저장된 이력 데이터 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

- 앱 \<\<- 인슐린펌프: BT_DATA_START_IND 메시지 전송 (대량 데이터 시작 알림)

- 앱 \<\<- 인슐린펌프: 저장된 이력 Data 전송(15일 기준, 15회 전송)

- 앱 \<\<- 인슐린펌프: BT_DATA_END_IND 메시지 전송 (대량 데이터 종료 알림)

## **Message Types**

1.  BT_LOG_REQ(0x1D) (앱 -\> 인슐린펌프)

- 펌프에 저장된 이력 데이터를 요청한다

- msg_type: 0x1D

- Data length 0

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>1D</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

2.  BT_DATA_START_IND(0x0B) (인슐린펌프 -\> 앱)

- 대량 패킷 시작 알림, 주입 이력 데이터 시작 알림 (15일 기준)

- msg_type: 0x0B

- Data length 0

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0B</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

3.  대량 패킷 데이터(헤더없이 데이터만 전송)

- BT_DATA_START_IND 이후 시작하여 BT_DATA_END_IND까지 전송되는 대량 데이터 (15일 기준). 헤더 없이 데이터만 전송

- Data:

  - 인슐린펌프에 저장되는 있는 로그 Data: 14byte

| **Log Type**    | **Data Length (byte)** | **Description** |
|-----------------|------------------------|-----------------|
| Month           | 1                      | 월              |
| Date            | 1                      | 일              |
| Base_Total      | 2                      | 기초 총량       |
| Eat_Total       | 2                      | 식사 총량       |
| Morning_Total   | 2                      | 아침시간 주입량 |
| Afternoon_Total | 2                      | 점심시간 주입량 |
| Evening_Total   | 2                      | 저녁시간 주입량 |
| Append_Total    | 2                      | 추가주입 총량   |

- **Packet Structure**

  - **최대 15일 기준 전송**

  - **BT_DATA_END_IND(0x0C) 패킷이 수신되면 멈춤**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td colspan="2" style="text-align: center;"><strong>기초총량</strong></td>
<td colspan="2" style="text-align: center;"><strong>식사총량</strong></td>
<td colspan="2" style="text-align: center;"><strong>아침시간 주입량</strong></td>
<td colspan="2" style="text-align: center;"><strong>점심시간 주입량</strong></td>
<td colspan="2" style="text-align: center;"><strong>저녁시간 주입량</strong></td>
<td colspan="2" style="text-align: center;"><strong>추가주입 총량</strong></td>
<td colspan="6" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(6월 1일, 기초총량 0x0002, 식사총량 0x000C, 아침 0x0005, 점심 0x0004, 저녁 0x0003, 추가주입 0x0005)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>06</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td colspan="2" style="text-align: center;"><strong>0200</strong></td>
<td colspan="2" style="text-align: center;"><strong>0C00</strong></td>
<td colspan="2" style="text-align: center;"><strong>0500</strong></td>
<td colspan="2" style="text-align: center;"><strong>0400</strong></td>
<td colspan="2" style="text-align: center;"><strong>0300</strong></td>
<td colspan="2" style="text-align: center;"><strong>0500</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
</tbody>
</table>

4.  BT_DATA_END_IND(0x0C) (인슐린펌프 -\> 앱)

- 대량 패킷 종료 알림, 주입 이력 데이터 종료 알림

- msg_type: 0x0C

- Data length: 0

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0C</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

# 일시 정지

## **Description**

1.  인슐린 펌프 동작을 잠시 정지하는 기능을 제어한다.

## **Message Sequence Flow**

1.  일시 정지 Flow

- 앱 -\>\> 인슐린펌프: BT_STOP_CTRL_REQ (일시 정지 또는 해제 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

## **Message Types**

1.  BT_STOP_CTRL_REQ(0x0D) (앱 -\> 인슐린펌프)

- 일시 정지 상태를 제어한다.

- msg_type: 0x0D

- Data length: 1

- Data:

  - pause_state: 1byte. BOOL type. 설정할 일시 정지 상태.

| **Stop State** | **Value** | **Description**     |
|----------------|-----------|---------------------|
| FALSE          | 0         | 일시 정지 상태 해제 |
| TRUE           | 1         | 일시 정지 설정      |

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 3%" />
<col style="width: 16%" />
<col style="width: 2%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0D</strong></td>
<td style="text-align: center;"><strong>1</strong></td>
<td style="text-align: center;"><strong>일시정지 설정(1)/해제(0)</strong></td>
<td colspan="16" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(일시 정지 설정) (앱 -\> 인슐린펌프)

|   0    |   1    |   2    |  3  |  4  |  5  |  6  |  7  |  8  |  9  | 10  | 11  | 12  | 13  | 14  | 15  | 16  | 17  | 18  | 19  |
|:------:|:------:|:------:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **EF** | **0D** | **01** | 01  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  |

- 응답 데이터, BT_MSG_RES (인슐린펌프 -\> 앱)

|   0    |   1    |   2    |  3  |  4  |  5  |  6  |  7  |  8  |  9  | 10  | 11  | 12  | 13  | 14  | 15  | 16  | 17  | 18  | 19  |
|:------:|:------:|:------:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **EF** | **00** | **0D** | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  |

# 설정

## **Description**

1.  인슐린 펌프에 여러 기능들을 설정한다.

## **Message Sequence Flow**

1.  기초 값 설정 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_TIME_BASE_SET_REQ (기초 값 설정 요청, 6회 전송)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

- 앱 \<\<- 인슐린펌프: BT_SET_RES (설정 요청에 대한 답변)

2.  식사 값 설정 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_MEAL_SET_REQ (식사 값 설정 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

- 앱 \<\<- 인슐린펌프: BT_SET_RES (설정 요청에 답변)

## **Message Types**

1.  BT_TIME_BASE_SET_REQ(0x0F) (앱 -\> 인슐린펌프)

- 시간별 상세 기초 설정 (6회 전송)

- msg_type: 0x0F

- Data length: 9

- Data

  - time_param: 1 byte. 설정되는 시간들을 결정.

  - set_hour: 8 bytes. 시간당 기초 설정 값. 시간 time_param에 따라 정의

<table style="width:77%;">
<colgroup>
<col style="width: 23%" />
<col style="width: 15%" />
<col style="width: 38%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;"><strong>Time_param Value</strong></th>
<th style="text-align: center;"><strong>Hour_time</strong></th>
<th style="text-align: center;"><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="4" style="text-align: center;">1</td>
<td style="text-align: center;">hour_1</td>
<td>00시 ~ 01시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_2</td>
<td>01시 ~ 02시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_3</td>
<td>02시 ~ 03시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_4</td>
<td>03시 ~ 04시 사이의 설정 값</td>
</tr>
<tr>
<td rowspan="4" style="text-align: center;">2</td>
<td style="text-align: center;">hour_1</td>
<td>04시 ~ 05시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_2</td>
<td>05시 ~ 06시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_3</td>
<td>06시 ~ 07시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_4</td>
<td>07시 ~ 08시 사이의 설정 값</td>
</tr>
<tr>
<td rowspan="4" style="text-align: center;">3</td>
<td style="text-align: center;">hour_1</td>
<td>08시 ~ 09시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_2</td>
<td>09시 ~ 10시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_3</td>
<td>10시 ~ 11시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_4</td>
<td>11시 ~ 12시 사이의 설정 값</td>
</tr>
<tr>
<td rowspan="4" style="text-align: center;">4</td>
<td style="text-align: center;">hour_1</td>
<td>12시 ~ 13시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_2</td>
<td>13시 ~ 14시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_3</td>
<td>14시 ~ 15시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_4</td>
<td>15시 ~ 16시 사이의 설정 값</td>
</tr>
<tr>
<td rowspan="4" style="text-align: center;">5</td>
<td style="text-align: center;">hour_1</td>
<td>16시 ~ 17시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_2</td>
<td>17시 ~ 18시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_3</td>
<td>18시 ~ 19시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_4</td>
<td>19시 ~ 20시 사이의 설정 값</td>
</tr>
<tr>
<td rowspan="4" style="text-align: center;">6</td>
<td style="text-align: center;">hour_1</td>
<td>20시 ~ 21시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_2</td>
<td>21시 ~ 22시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_3</td>
<td>22시 ~ 23시 사이의 설정 값</td>
</tr>
<tr>
<td style="text-align: center;">hour_4</td>
<td>23시 ~ 24시 사이의 설정 값</td>
</tr>
</tbody>
</table>

- **Packet Structure**

  - time_param을 1~6까지 순차적으로 변경하며 6회 전송

<table style="width:100%;">
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 8%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0F</strong></td>
<td style="text-align: center;"><strong>09</strong></td>
<td style="text-align: center;"><strong>time_param (1~6)</strong></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_1 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_2 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_3 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_4 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="8" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제\
  (첫번째 패킷: 00~01시, 01~02시, 02시~03시, 03시~04시 모두 100 입력,\
  두번째 패킷: 04~05시, 05~06시, 06시~07시, 07시~08시 모두 100 입력,\
  세번째 패킷: 08~09시, 09~10시, 10시~11시, 11시~12시 모두 100 입력,\
  네번째 패킷: 12~13시, 13~14시, 14시~15시, 15시~16시 모두 100 입력,\
  다섯번째 패킷: 16~17시, 17~18시, 18시~19시, 19시~20시 모두 100 입력,\
  여섯번째 패킷: 20~21시, 21~22시, 22시~23시, 23시~24시 모두 100 입력,)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0F</strong></td>
<td style="text-align: center;"><strong>09</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0F</strong></td>
<td style="text-align: center;"><strong>09</strong></td>
<td style="text-align: center;"><strong>02</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0F</strong></td>
<td style="text-align: center;"><strong>09</strong></td>
<td style="text-align: center;"><strong>03</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0F</strong></td>
<td style="text-align: center;"><strong>09</strong></td>
<td style="text-align: center;"><strong>04</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0F</strong></td>
<td style="text-align: center;"><strong>09</strong></td>
<td style="text-align: center;"><strong>05</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>0F</strong></td>
<td style="text-align: center;"><strong>09</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
</tbody>
</table>

2.  BT_MEAL_SET_REQ(0x10) (앱 -\> 인슐린펌프)

- 식사 때 별로 주입량 설정

- msg_type: 0x10

- Data length: 3

- Data:

  - meal_sel: 1 byte. 식사 선택

| **Meal time**  | **Value** | **Description** |
|----------------|-----------|-----------------|
| meal_breakfast | 0         | 아침 식사       |
| meal_lunch     | 1         | 점심 식사       |
| meal_dinner    | 2         | 저녁 식사       |

  - inj_val: 2 byte. 설정할 인슐린 주입량

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 11%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>10</strong></td>
<td style="text-align: center;"><strong>03</strong></td>
<td style="text-align: center;"><strong>식사 선택 (아침, 점심, 저녁)</strong></td>
<td colspan="2" style="text-align: center;"><p><strong>인슐린 주입량</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="14" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(저녁식사, 7 주입)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>10</strong></td>
<td style="text-align: center;"><strong>03</strong></td>
<td style="text-align: center;"><strong>02</strong></td>
<td colspan="2" style="text-align: center;"><strong>0700</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
</tbody>
</table>

3.  BT_SET_RES(0x12) (인슐린펌프 -\> 앱)

- 설정 요청에 대한 응답

- msg_type: 0x12

- Data length: 8

- Data:

  - set_date(DATE type): 6byte. 설정한 날짜.(년/월/일/시/분/초)

  - insul_remain: 2 bytes. 인슐린 잔량.

- **Packet Structure**

<table>
<colgroup>
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>12</strong></td>
<td style="text-align: center;"><strong>08</strong></td>
<td><strong>년</strong></td>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="2" style="text-align: center;"><strong>인슐린 잔량 2byte</strong></td>
<td colspan="9" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(2015년 3월 31일 13시 04분 33초, 잔량 12,405)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>12</strong></td>
<td style="text-align: center;"><strong>08</strong></td>
<td style="text-align: center;"><strong>0F</strong></td>
<td style="text-align: center;"><strong>03</strong></td>
<td style="text-align: center;"><strong>1F</strong></td>
<td style="text-align: center;"><strong>0D</strong></td>
<td style="text-align: center;"><strong>04</strong></td>
<td style="text-align: center;"><strong>21</strong></td>
<td colspan="2" style="text-align: center;"><strong>7530</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
</tbody>
</table>

# 주입 요청

## **Description**

1.  인슐린 주입을 제어한다.

## **Message Sequence Flow**

1.  운동모드 설정 및 주입 요청, 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_EXERCISE_SET_REQ 메시지 전송 (운동모드 설정 및 주입 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (운동모드 진행중이면 res_code invalid 0x01 전송)

- 앱 \<\<- 인슐린펌프: BT_EXERCISE_INJ_START_IND 메시지 전송 (운동모드 시작 알림)

- 앱 \<\<- 인슐린펌프: BT_EXERCISE_INJ_STOP_IND 메시지 전송 (운동모드 종료 알림)

2.  회식모드 설정 및 주입 요청, 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_RECEPTION_SET_REQ 메시지 전송 (회식모드 설정 및 주입 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (회식모드 진행중이면 res_code invalid 0x01 전송)

- 앱 \<\<- 인슐린펌프: BT_RECEPTION_INJ_START_IND 메시지 전송 (회식모드 시작 알림)

- 앱 \<\<- 인슐린펌프: BT_RECEPTION_INJ_STOP_IND 메시지 전송 (회식모드 종료 알림)

3.  주입정보 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_INJ_INFO_REQ 메시지 전송 (주입정보 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

- 앱 \<\<- 인슐린펌프: BT_INJ_INFO_RES 메시지 전송 (주입정보 응답)

4.  주입 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_INJ_REQ 메시지 전송 (주입 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

- 앱 \<\<- 인슐린펌프: BT_INJ_START_IND 메시지 전송 (주입 시작 알림)

- 앱 \<\<- 인슐린펌프: BT_INJ_STOP_IND 메시지 전송 (주입 종료 알림)

5.  강제 정지 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프 : BT_INJ_STOP_REQ 메시지 전송 (강제 정지 요청)

- 앱 \<\<- 인슐린펌프 : BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

## **Message Types**

1.  BT_EXERCISE_SET_REQ(0x13) (앱 -\> 인슐린펌프)

- 기초설정 중 운동모드를 설정하도록 요청한다. **<u>(단 운동모드가 진행되는 상황에서는 설정 요청시 Message response로 현재 상태에서 요청처리 불가인 RES_INVALID_STATUS를 전달)</u>**

- msg_type: 0x13

- Data length: 3

- Data:

  - inj_sel: 1 byte. 주입할 설정 선택

| **Exercise selection** | **Value** | **Description**   |
|------------------------|-----------|-------------------|
| basel_exmode_on        | 1         | 운동모드 설정     |
| basel_exmode_off       | 0         | 운동모드 취소     |

  - basal_exercise_time_val: 1 bytes. 운동시간 (1시간 단위로 1~8시간까지 설정 가능)

  - basal_exercise_range_val: 1 bytes. 운동감량 (**<u>20단위로 20~80까지</u>** 설정가능)

- **Packet Structure**

<table>
<colgroup>
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 10%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 2%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>13</strong></td>
<td style="text-align: center;"><strong>03</strong></td>
<td><strong>운동모드 설정(1)/취소(0)</strong></td>
<td style="text-align: center;"><strong>운동시간</strong></td>
<td style="text-align: center;"><strong>운동감량</strong></td>
<td colspan="14" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(운동설정, 5시간, 30% 감량)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **13** | **03** | **01** | **05** | **1E** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

2.  BT_EXERCISE_INJ_START_IND(0x29) (운동시작) (인슐린펌프 -\> 앱)

- 기초주입 중 운동모드를 시작을 알린다.

- msg_type: 0x29

- Data length: 8

- Data:

  - Exercise_Time: 1byte. 운동시간 설정 값

  - Exercise_Value: 1byte.운동감량 설정 값

  - set_year(DATE type): 6byte. 운동 기초주입시작 날짜(년/월/일/시/분/초)

- **Packet Structure**

<table style="width:100%;">
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 9%" />
<col style="width: 9%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>29</strong></td>
<td style="text-align: center;"><strong>08</strong></td>
<td><strong>운동시간 설정 값</strong></td>
<td style="text-align: center;"><strong>운동감량 설정 값</strong></td>
<td style="text-align: center;"><strong>년</strong></td>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="9" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(3시간, 30% 감량, 2026년 6월 1일 5시 21분 10초)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **29** | **08** | **03** | **1E** | **1A** | **06** | **01** | **05** | **15** | **10** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

3.  BT_EXERCISE_INJ_STOP_IND(0x2A) (인슐린펌프 -\> 앱)

- 기초주입 중 운동모드를 종료를 알린다..

- msg_type: 0x2A

- Data length: 6

- Data:

  - set_year(DATE type): 6byte. 운동 기초주입종료 날짜(년/월/일/시/분/초)

- **Packet Structure**

<table>
<colgroup>
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>2A</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td><strong>년</strong></td>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="11" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(2026년 6월 1일 8시 21분 10초)

| 순번 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| 데이터 | **EF** | **2A** | **06** | **1A** | **06** | **01** | **08** | **15** | **10** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

4.  BT_RECEPTION_SET_REQ(0x14) (앱 -\> 인슐린펌프)

- 식사설정 중 회식모드를 설정하도록 요청한다. **<u>(단 회식모드가 진행되는 상황에서는 설정 요청시 Message response로 현재 상태에서 요청처리 불가인 RES_INVALID_STATUS를 전달)</u>**

- msg_type: 0x14

- Data length: 2

- Data:

  - inj_sel: 1 byte. 주입할 설정 선택

| **Exercise selection** | **Value** | **Description**   |
|------------------------|-----------|-------------------|
| basel_receptmode_on    | 1         | 회식모드 설정     |
| basel_receptmode_off   | 0         | **회식모드 취소** |

  - eat_recetion_time_val: 1 bytes. 회식시간 (1시간 단위로 1~8시간까지 설정 가능)

- **Packet Structure**

<table>
<colgroup>
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 10%" />
<col style="width: 6%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>14</strong></td>
<td style="text-align: center;"><strong>02</strong></td>
<td style="text-align: center;"><strong>회식모드 설정(1)/취소(0)</strong></td>
<td style="text-align: center;"><strong>회식시간</strong></td>
<td colspan="15" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(회식모드 설정, 3시간)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **14** | **02** | **01** | **03** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

5.  BT_RECEPTION_INJ_START_IND(0x2B) (인슐린펌프 -\> 앱)

- 식사주입 중 회식모드를 시작을 알린다..

- msg_type: 0x2B

- Data length: **7**

- Data:

  - Reception_Time: 1byte. 회식시간 설정 값

  - set_year(DATE type): 6byte. 식사 회식모드주입시작 날짜(년/월/일/시/분/초)

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 9%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>2B</strong></td>
<td style="text-align: center;"><strong>07</strong></td>
<td><strong>회식시간 설정 값</strong></td>
<td style="text-align: center;"><strong>년</strong></td>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="10" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(3시간, 2026년 6월 1일 5시 21분 10초)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **2B** | **07** | **03** | **1A** | **06** | **01** | **05** | **15** | **10** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

6.  BT_RECEPTION_INJ_STOP_IND(0x2C) (인슐린펌프 -\> 앱)

- 식사주입 중 회식모드를 종료를 알린다..

- msg_type: 0x2C

- Data length: 6

- Data:

  - set_year(DATE type): 6byte. 식사 **<u>회식모드 주입종료 날짜(</u>**년/월/일/시/분/초)

- **Packet Structure**

<table>
<colgroup>
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>2C</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td><strong>년</strong></td>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="11" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(2026년 6월 1일 8시 21분 10초)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **2C** | **06** | **1A** | **06** | **01** | **08** | **15** | **10** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

7.  BT_INJ_INFO_REQ(0x15) (앱 -\> 인슐린펌프)

- 주입 정보 요청

- msg_type: 0x15

- Data length: 1

- Data:

  - inj_info: 1 byte. 원하는 인슐린 주입 설정 선택

| **Injection selection** | **Value** | **Description** |
|-------------------------|-----------|-----------------|
| inj_sel_eat             | 0         | 식사주입        |
| ink_sel_append          | 1         | 추가주입        |

- **Packet Structure**

<table>
<colgroup>
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 16%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>15</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td style="text-align: center;"><strong>식사(0) 또는 추가주입(1) 선택</strong></td>
<td colspan="16" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제

|   0    |   1    |   2    |   3    |  4  |  5  |  6  |  7  |  8  |  9  | 10  | 11  | 12  | 13  | 14  | 15  | 16  | 17  | 18  | 19  |
|:------:|:------:|:------:|:------:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **EF** | **15** | **01** | **00** | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  |

8.  BT_INJ_INFO_RES(0x16) (인슐린펌프-\>앱)

- 주입 정보 응답

- msg_type: 0x16

- Data length: 11

- Data:

  - inj_info: 1 byte. 주입 정보 종류 (인슐린펌프에서 식사 주입 요청일 경우 자동으로 아침,점심,저녁 정보값 중 선택하여 전달)

| **Injection selection** | **Value** | **Description**     |
|-------------------------|-----------|---------------------|
| inj_info_breakfast      | **1**     | 아침 식사 주입 선택 |
| inj_info_lunch          | **2**     | 점심 식사 주입 선택 |
| inj_info_dinner         | **3**     | 저녁 식사 주입 선택 |
| inj_info_append         | **4**     | 추가 주입 선택      |

  - set_date(DATE type): 6byte. 설정한 날짜(년/월/일/시/분/초).

  - insul_set: 2byte. 인슐린 설정 값

  - insul_remain: 2byte. 인슐린 잔량


- **Packet Structure**

<table style="width:100%;">
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 9%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>16</strong></td>
<td style="text-align: center;"><strong>0B</strong></td>
<td style="text-align: center;"><strong>주입 종류 (아침,점심,저녁,추가)</strong></td>
<td style="text-align: center;"><strong>년</strong></td>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="2" style="text-align: center;"><strong>인슐린 설정 값 2byte</strong></td>
<td colspan="2" style="text-align: center;"><strong>인슐린 잔량 2byte</strong></td>
<td colspan="6" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(점심식사, 2026년 6월 1일 5시 21분 10초, 설정 값 5, 잔량 12,405)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>16</strong></td>
<td style="text-align: center;"><strong>0B</strong></td>
<td style="text-align: center;"><strong>02</strong></td>
<td style="text-align: center;"><strong>1A</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td style="text-align: center;"><strong>05</strong></td>
<td style="text-align: center;"><strong>15</strong></td>
<td style="text-align: center;"><strong>10</strong></td>
<td colspan="2" style="text-align: center;"><strong>0500</strong></td>
<td colspan="2" style="text-align: center;"><strong>7530</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
</tbody>
</table>

9.  BT_INJ_REQ(0x17) (앱 -\> 인슐린펌프)

- 인슐린 주입을 하도록 요청한다.

- msg_type: 0x17

- Data length: 3

- Data:

  - inj_sel: 1 byte. 주입할 설정 선택

| **Injection selection** | **Value** | **Description** |
|-------------------------|-----------|-----------------|
| inj_sel_eat             | 0         | 식사주입        |
| ink_sel_append          | 1         | 추가주입        |

  - inj_val: 2 bytes. 인슐린 설정 값 **<u>//장비의 설정 값과 비교하여 다른면 에러처리 필요</u>**


- **Packet Structure**

<table>
<colgroup>
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 13%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>17</strong></td>
<td style="text-align: center;"><strong>03</strong></td>
<td style="text-align: center;"><strong>식사(0) 또는 추가주입(1) 선택</strong></td>
<td colspan="2" style="text-align: center;"><strong>인슐린 설정 값</strong></td>
<td colspan="14" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(식사주입 요청, 설정 값 5)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>17</strong></td>
<td style="text-align: center;"><strong>03</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="2" style="text-align: center;"><strong>0500</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
</tbody>
</table>

10.  BT_INJ_START_IND(0x3A) (인슐린펌프-\>앱)

- 주입 시작을 알린다.

- msg_type: 0x3A

- Data length: 0

- Data:

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>3A</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

11.  BT_INJ_STOP_IND(0x3B) (인슐린펌프-\>앱)

- 주입 종료를 알린다.

- msg_type: 0x3B

- Data length: 11

- Data:

 - 주입 종류(식사주입(0), 추가주입(1)): 1byte

 - set_year(DATE type): 6byte. 주입종료 시점(년/월/일/시/분/초)

 - 주입정보 종류에 따른 금일 식사 또는 추가주입 누적량: 2byte

 - insul_remain: 2byte. 인슐린 잔량

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 6%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>3B</strong></td>
<td style="text-align: center;"><strong>0B</strong></td>
<td><strong>주입 종류</strong></td>
<td style="text-align: center;"><strong>년</strong></td>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="2" style="text-align: center;"><strong>금일 누적량 2byte</strong></td>
<td colspan="2" style="text-align: center;"><strong>인슐린 잔량 2byte</strong></td>
<td colspan="6" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(점심식사, 2026년 6월 1일 5시 21분 10초, 설정 값 5, 잔량 12,405)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 6%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>3B</strong></td>
<td style="text-align: center;"><strong>0B</strong></td>
<td style="text-align: center;"><strong>02</strong></td>
<td style="text-align: center;"><strong>1A</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td style="text-align: center;"><strong>05</strong></td>
<td style="text-align: center;"><strong>15</strong></td>
<td style="text-align: center;"><strong>10</strong></td>
<td colspan="2" style="text-align: center;"><strong>0500</strong></td>
<td colspan="2" style="text-align: center;"><strong>7530</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
</tbody>
</table>

12.  BT_INJ_STOP_REQ(0x37) (앱 -\> 인슐린펌프)

- 강제 정지 상태를 제어한다.

- msg_type: 0x37

- Data length: 1

- Data:

 - pause_state(BOOL type): 1byte. 강제 정지 설정/해제

| **Stop State** | **Value** | **Description**     |
|----------------|-----------|---------------------|
| FALSE          | 0         | 강제 정지 상태 해제 |
| TRUE           | 1         | 강제 정지 설정      |

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 16%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 3%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>37</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td style="text-align: center;"><strong>강제정지 설정(1)/해제(0)</strong></td>
<td colspan="16" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(강제 정치 상태 해제)

|   0    |   1    |   2    |   3    |  4  |  5  |  6  |  7  |  8  |  9  | 10  | 11  | 12  | 13  | 14  | 15  | 16  | 17  | 18  | 19  |
|:------:|:------:|:------:|:------:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **EF** | **37** | **01** | **00** | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  | 00  |

# 오류 상태 알림

## **Description**

1.  인슐린 펌프 사용 중 발생할 수 있는 오류를 알린다.

## **Message Sequence Flow**

1.  에러 메시지 알림 Flow

- 앱 \<\<- 인슐린펌프 : BT_ERR_IND 메시지 전송 (경고, 알람 등 이슈사항 알림)

## **Message Types**

1.  BT_ERR_IND(0x19) (인슐린펌프-\>앱)

- 발생한 경고나 알람을 알린다.

- msg_type: 0x19

- Data length: 7

- Data:

  - err_type: 1 byte. 발생된 오류

| **State** | **Value** | **Description** |
|----|----|----|
| err_none | 0x00 | 특이 사항 없음 |
| err_niddle_clogged | 0x01 | 주사기 바늘 막힘 -\> 주사기 막힘 |
| err_inj_fault | 0x02 | 주입불가, 모터이상동작 |
| err_low_batt | 0x03 | 밧데리 부족 -\> 배터리부족 |
| err_pause | 0x04 | 오류 정지 상태 -\> 일시정지 설정/해제 모드 |
| err_insul_shortage | 0x05 | 인슐린 부족 -\> 인슐린 잔량 부족 |
| err_inj_time_over | 0x06 | 시간제한 -\> 추가된 명령 (2,3시간 식사제한) |
| err_insul_day_total_over | 0x07 | 1일초과 (식사주입, 추가주입) -\> 추가된 명령 |
| err_insul_unit_over | 0x08 | 단위초과 (식사주입) -\> 추가된 명령 |
| err_insul_on_going | 0x09 | 인슐린 현재 주입중 |
| err_unknown_err | 0x0A | 원인 불명 에러 (앞 전에 Value = 6이였음) |

  - set_year(DATE type) 6byte. 모든 에러 이력 발생 시간**<u>(</u>**년/월/일/시/분/초)

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 9%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>19</strong></td>
<td style="text-align: center;"><strong>07</strong></td>
<td style="text-align: center;"><strong>err_type</strong></td>
<td style="text-align: center;"><strong>년</strong></td>
<td style="text-align: center;"><strong>월</strong></td>
<td style="text-align: center;"><strong>일</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="10" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(주사기 바늘 막힘, 2026년 6월 1일 5시 21분 10초)

| 순번 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| 데이터 | **EF** | **19** | **07** | **01** | **1A** | **06** | **01** | **05** | **15** | **10** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

# 이력 데이터 처리 

## **Description**

1.  펌프의 이력 데이터 처리에 관련된 메시지들을 정의한다.

## **Message Sequence Flow**

1.  금일 이력 데이터 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프 : BT_LOG_INJ_QNT_REQ 메시지 전송 (금일 누적량 이력 정보 요청)

- 앱 \<\<- 인슐린펌프 : BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

- 앱 \<\<- 인슐린펌프 : BT_LOG_INJ_QNT_IND 메시지 전송 (금일 누적량 이력 정보 전달)

## **Message Types**

1.  BT_LOG_INJ_QNT_REQ(0x1E) (앱 -\> 인슐린펌프)

- 금일 주입 누적량 이력에 대한 정보를 요청한다.

- msg_type: 0x1E

- Data length: 0

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>1E</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

2.  BT_LOG_INJ_QNT_IND(0x1F) (인슐린펌프 -\> 앱)

- 금일 주입 누적량 이력에 대한 정보를 전달한다.

- msg_type: 0x1F

- Data length: 13

- Data

| **Data** | **Description** |
|----------|-----------------|
| hour     | 데이터 시간     |
| min      | 데이터 분       |
| sec      | 데이터 초       |

  - 주입 누적량: 10 bytes. 해당 주입 누적량

| **Injection Type** | **Data length (byte)** | **Description** |
|--------------------|------------------------|-----------------|
| base               | 2                      | 기초 누적량     |
| breakfast          | 2                      | 아침 누적량     |
| lunch              | 2                      | 점심 누적량     |
| dinner             | 2                      | 저녁 누적량     |
| add                | 2                      | 추가 누적량     |

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>1F</strong></td>
<td style="text-align: center;"><strong>0D</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="2" style="text-align: center;"><strong>기초 누적량 (2byte)</strong></td>
<td colspan="2" style="text-align: center;"><strong>아침 누적량 (2byte)</strong></td>
<td colspan="2" style="text-align: center;"><strong>점심 누적량 (2byte)</strong></td>
<td colspan="2" style="text-align: center;"><strong>저녁 누적량 (2byte)</strong></td>
<td colspan="2" style="text-align: center;"><strong>추가 누적량 (2byte)</strong></td>
<td colspan="4" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(5시 21분 10초, 기초 누적량 5, 아침 누적량 4, 점심 누적량 5, 저녁 누적량 6, 추가 누적량 10)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>1F</strong></td>
<td style="text-align: center;"><strong>0D</strong></td>
<td style="text-align: center;"><strong>05</strong></td>
<td style="text-align: center;"><strong>15</strong></td>
<td style="text-align: center;"><strong>10</strong></td>
<td colspan="2" style="text-align: center;"><strong>0500</strong></td>
<td colspan="2" style="text-align: center;"><strong>0400</strong></td>
<td colspan="2" style="text-align: center;"><strong>0500</strong></td>
<td colspan="2" style="text-align: center;"><strong>0600</strong></td>
<td colspan="2" style="text-align: center;"><strong>0A00</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
</tbody>
</table>

# 설정정보 확인

## **Description**

1.  펌프의 설정정보를 요청하고, 전달한다

## **Message Sequence Flow**

1.  식사 설정 값 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_EAT_VALUE_REQ 메시지 전송 (식사 설정 값 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

- 앱 \<\<- 인슐린펌프: BT_EAT_VALUE_RES 메시지 전송 (식사 설정 값 전달)

2.  기초 설정 값 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_BASE_VALUE_REQ 메시지 전송 (기초 설정 값 요청)

- 앱 \<\<- 인슐린펌프: BT_MSG_RES 메시지 전송 (res_code 정상 0x00 전송)

- 앱 \<\<- 인슐린펌프: BT_BASE_VALUE_RES 메시지 전송 (기초 설정 값 전달)

## **Message Types**

1.  BT_EAT_VALUE_REQ(0x2D) (앱 -\> 인슐린펌프)

- 식사(아침, 점심, 저녁) 설정 값을 요청한다..

- msg_type: 0x2D

- Data length: 0.

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>2D</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

2.  BT_EAT_VALUE_RES(0x2E) (인슐린펌프 -\> 앱)

- 식사(아침, 점심, 저녁) 설정 값을 전달한다..

- msg_type: 0x2E

- Data length: 6.

- Data

| **Eat time**  | **Data Length** | **Description** |
|---------------|:---------------:|-----------------|
| Eat_breakfast |        2        | 아침 식사       |
| Eat_lunch     |        2        | 점심 식사       |
| Eat_dinner    |        2        | 저녁 식사       |

  - 추가 주입은 기본 설정 값이 5로 고정
  
- **Packet structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>2E</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td colspan="2" style="text-align: center;"><strong>아침 설정 값 (2byte)</strong></td>
<td colspan="2" style="text-align: center;"><strong>점심 설정 값 (2byte)</strong></td>
<td colspan="2" style="text-align: center;"><strong>저녁 설정 값 (2byte)</strong></td>
<td colspan="11" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(아침 식사: 783 점심 식사: 5,919, 저녁 식사: 9,222)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>2E</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td colspan="2" style="text-align: center;"><strong>0F03</strong></td>
<td colspan="2" style="text-align: center;"><strong>1F17</strong></td>
<td colspan="2" style="text-align: center;"><strong>0624</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
</tbody>
</table>

3.  BT_BASE_VALUE_REQ(0x2F) (앱 -\> 인슐린펌프)

- 기초 설정 값을 요청한다.

- msg_type: 0x2F

- Data length: 0

- **Packet structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>2F</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

4.  BT_BASE_VALUE_RES(0x30) (인슐린펌프 -\> 앱)

- 기초 설정 값을 전달한다.

- msg_type: 0x30

- Data length: 17

- Data

  - time_param: 1 byte. 설정되는 시간들을 결정.

  - set_hour: 16 bytes. 시간당 기초 설정 값. 시간 time_param에 따라 정의

<table style="width:82%;">
<colgroup>
<col style="width: 25%" />
<col style="width: 20%" />
<col style="width: 36%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;"><strong>time_param Value</strong></th>
<th style="text-align: center;"><strong>hour_time</strong></th>
<th style="text-align: center;"><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="8">1</td>
<td>hour_1</td>
<td>0시 ~ 1시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_2</td>
<td>1시 ~ 2시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_3</td>
<td>2시 ~ 3시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_4</td>
<td>3시 ~ 4시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_5</td>
<td>4시 ~ 5시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_6</td>
<td>5시 ~ 6시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_7</td>
<td>6시 ~ 7시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_8</td>
<td>7시 ~ 8시 사이의 설정 값</td>
</tr>
<tr>
<td rowspan="8">2</td>
<td>hour_1</td>
<td>8시 ~ 9시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_2</td>
<td>9시 ~ 10시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_3</td>
<td>10시 ~ 11시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_4</td>
<td>11시 ~ 12시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_5</td>
<td>12시 ~ 13시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_6</td>
<td>13시 ~ 14시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_7</td>
<td>14시 ~ 15시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_8</td>
<td>15시 ~ 16시 사이의 설정 값</td>
</tr>
<tr>
<td rowspan="8">3</td>
<td>hour_1</td>
<td>16시 ~ 17시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_2</td>
<td>17시 ~ 18시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_3</td>
<td>18시 ~ 19시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_4</td>
<td>19시 ~ 20시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_5</td>
<td>20시 ~ 21시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_6</td>
<td>21시 ~ 22시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_7</td>
<td>22시 ~ 23시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_8</td>
<td>23시 ~ 24시 사이의 설정 값</td>
</tr>
</tbody>
</table>

- **Packet Structure**

  - time_param을 1~3까지 순차적으로 변경하며 3회 전송

<table style="width:100%;">
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 8%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>30</strong></td>
<td style="text-align: center;"><strong>11</strong></td>
<td style="text-align: center;"><strong>time_param</strong></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_1 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_2 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_3 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_4 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_5 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_6 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_7 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>hour_8 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
</tr>
</tbody>
</table>

- 예제\
  (첫번째 줄: 00~01시, 01~02시, 02시~03시, 03시~04시 모두 100 입력,\
  두번째 줄: 04~05시, 05~06시, 06시~07시, 07시~08시 모두 100 입력,\
  세번째 줄: 08~09시, 09~10시, 10시~11시, 11시~12시 모두 100 입력)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>30</strong></td>
<td style="text-align: center;"><strong>17</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
</tr>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>30</strong></td>
<td style="text-align: center;"><strong>17</strong></td>
<td style="text-align: center;"><strong>02</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
</tr>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>30</strong></td>
<td style="text-align: center;"><strong>17</strong></td>
<td style="text-align: center;"><strong>03</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
</tr>
</tbody>
</table>

# 설정 통보

## **Description**

1.  펌프의 설정정보가 변경될 경우 이를 앱으로 통보한다.

## **Message Sequence Flow**

1.  기초 설정 값 알림 Flow

- 앱 \<\<- 인슐린펌프: BT_BASE_VALUE_IND 메시지 전송 (기초 설정 값 변경 시 전달)

2.  식사 설정 값 알림 Flow

- 앱 \<\<- 인슐린펌프: BT_LOG_INJ_SET_1_IND 메시지 전송 (식사 설정 값 변경 시 전달)

## **Message Types**

1.  BT_BASE_VALUE_IND(0x40) (인슐린펌프 -\> 앱)

- (인슐린장치에서) 기초 설정 값 변경 시 전달

- msg_type: 0x40

- Data length: 17

- Data

  - time_param: 1 byte. 설정되는 시간들을 결정.

  - set_hour: 16 bytes. 시간당 기초 설정 값. 시간 time_param에 따라 정의

<table style="width:82%;">
<colgroup>
<col style="width: 25%" />
<col style="width: 20%" />
<col style="width: 36%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;"><strong>time_param Value</strong></th>
<th style="text-align: center;"><strong>hour_time</strong></th>
<th style="text-align: center;"><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="8">1</td>
<td>hour_1</td>
<td>0시 ~ 1시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_2</td>
<td>1시 ~ 2시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_3</td>
<td>2시 ~ 3시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_4</td>
<td>3시 ~ 4시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_5</td>
<td>4시 ~ 5시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_6</td>
<td>5시 ~ 6시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_7</td>
<td>6시 ~ 7시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_8</td>
<td>7시 ~ 8시 사이의 설정 값</td>
</tr>
<tr>
<td rowspan="8">2</td>
<td>hour_1</td>
<td>8시 ~ 9시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_2</td>
<td>9시 ~ 10시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_3</td>
<td>10시 ~ 11시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_4</td>
<td>11시 ~ 12시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_5</td>
<td>12시 ~ 13시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_6</td>
<td>13시 ~ 14시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_7</td>
<td>14시 ~ 15시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_8</td>
<td>15시 ~ 16시 사이의 설정 값</td>
</tr>
<tr>
<td rowspan="8">3</td>
<td>hour_1</td>
<td>16시 ~ 17시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_2</td>
<td>17시 ~ 18시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_3</td>
<td>18시 ~ 19시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_4</td>
<td>19시 ~ 20시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_5</td>
<td>20시 ~ 21시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_6</td>
<td>21시 ~ 22시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_7</td>
<td>22시 ~ 23시 사이의 설정 값</td>
</tr>
<tr>
<td>hour_8</td>
<td>23시 ~ 24시 사이의 설정 값</td>
</tr>
</tbody>
</table>

- **Packet Structure**

  - time_param을 1~3까지 순차적으로 변경하며 3회 전송

<table style="width:100%;">
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 8%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>40</strong></td>
<td style="text-align: center;"><strong>11</strong></td>
<td style="text-align: center;"><strong>Time_param</strong></td>
<td colspan="2" style="text-align: center;"><p><strong>Hour_1 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>Hour_2 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>Hour_3 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>Hour_4 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>Hour_5 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>Hour_6 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>Hour_7 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
<td colspan="2" style="text-align: center;"><p><strong>Hour_8 설정값</strong></p>
<p><strong>(2byte)</strong></p></td>
</tr>
</tbody>
</table>

- 예제\
  (첫번째 줄: 00~01시, 01~02시, 02시~03시, 03시~04시 모두 100 입력,\
  두번째 줄: 04~05시, 05~06시, 06시~07시, 07시~08시 모두 100 입력,\
  세번째 줄: 08~09시, 09~10시, 10시~11시, 11시~12시 모두 100 입력)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>40</strong></td>
<td style="text-align: center;"><strong>17</strong></td>
<td style="text-align: center;"><strong>01</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
</tr>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>40</strong></td>
<td style="text-align: center;"><strong>17</strong></td>
<td style="text-align: center;"><strong>02</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
</tr>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>40</strong></td>
<td style="text-align: center;"><strong>17</strong></td>
<td style="text-align: center;"><strong>03</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
<td colspan="2" style="text-align: center;"><strong>6400</strong></td>
</tr>
</tbody>
</table>

2.  BT_LOG_INJ_SET_1_IND(0x20) (인슐린펌프 -\> 앱)

- (인슐린펌프에서) 아침/점심/저녁 식사주입 변경시 BLE로 자동 통보하는 기능

- 현재 주입 설정 이력 정보: 아침, 점심, 저녁

- msg_type: 0x20

- Data length: 9

- Data

| **Data**               | **Data length (byte)** | **Description** |
|------------------------|------------------------|-----------------|
| set_hour               | 1                      | 설정한 시간     |
| set_min                | 1                      | 설정한 분       |
| set_sec                | 1                      | 설정한 초       |
| breakfast              | 2                      | 아침 설정값     |
| lunch                  | 2                      | 점심 설정값     |
| dinner                 | 2                      | 저녁 설정값     |
| ~~add~~ (전송 불 필요) | ~~2~~                  | ~~추가 설정값~~ |

  - 추가 주입은 기본 설정 값이 5로 고정되어 있으며, 매 추가 주입 시 변경 후 원위치 됨. 따라서 변경 값을 BLE로 전송할 필요 없음

  - 전역변수로 수정하는 방안 협의 후 FW 수정 필요

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>20</strong></td>
<td style="text-align: center;"><strong>09</strong></td>
<td style="text-align: center;"><strong>시</strong></td>
<td style="text-align: center;"><strong>분</strong></td>
<td style="text-align: center;"><strong>초</strong></td>
<td colspan="2" style="text-align: center;"><strong>아침 설정 값 (2byte)</strong></td>
<td colspan="2" style="text-align: center;"><strong>점심 설정 값 (2byte)</strong></td>
<td colspan="2" style="text-align: center;"><strong>저녁 설정 값 (2byte)</strong></td>
<td colspan="8" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(5시 21분 10초, 아침 4, 점심 5, 저녁 6)

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>20</strong></td>
<td style="text-align: center;"><strong>09</strong></td>
<td style="text-align: center;"><strong>05</strong></td>
<td style="text-align: center;"><strong>15</strong></td>
<td style="text-align: center;"><strong>10</strong></td>
<td colspan="2" style="text-align: center;"><strong>0400</strong></td>
<td colspan="2" style="text-align: center;"><strong>0500</strong></td>
<td colspan="2" style="text-align: center;"><strong>0600</strong></td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
<td style="text-align: center;">00</td>
</tr>
</tbody>
</table>

# 앱(App) 패스워드(Password) 변경

## **Description**

1.  앱(App) Password 정보를 변경한다.

## **Message Sequence Flow**

1.  패스워드 전송 Flow

- 앱 -\>\> 인슐린펌프: BT_PRS_APP_PASSWD_IND 메시지 전송 (기존 Password 정보 전달)

2.  신규 패스워드 전송 Flow

- 앱 \<\<- 인슐린펌프: BT_NEW_APP_PASSWD_IND 메시지 전송 (신규 Password 정보 전달)

3.  패스워드 요청 및 응답 Flow

- 앱 -\>\> 인슐린펌프: BT_PRS_APP_PASSWD_REQ 메시지 전송 (현재 Password 조회 요청)

- 앱 \<\<- 인슐린펌프: BT_PRS_APP_PASSWD_RES 메시지 전송 (현재 Password 전달)

## **Message Types**

1.  BT_PRS_APP_PASSWD_IND(0x3C) (앱 -\> 인슐린펌프)

- 기존 Password정보를 전달한다.

- msg_type: 0x3C

- Data length: 6.

| **구분**            | **Data Length** | **Description**          |
|---------------------|:---------------:|--------------------------|
| 1<sup>st</sup> byte |        1        | Password 첫번째 바이트   |
| 2<sup>nd</sup> byte |        1        | Password 두번째 바이트   |
| 3<sup>rd</sup> byte |        1        | Password 세번째 바이트   |
| 4<sup>th</sup> byte |        1        | Password 네번째 바이트   |
| 5<sup>th</sup> byte |        1        | Password 다섯번째 바이트 |
| 6<sup>th</sup> byte |        1        | Password 여섯번째 바이트 |

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>3C</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td style="text-align: center;"><strong>첫번째 PW</strong></td>
<td style="text-align: center;"><strong>두번째 PW</strong></td>
<td style="text-align: center;"><strong>세번째 PW</strong></td>
<td style="text-align: center;"><strong>네번째 PW</strong></td>
<td style="text-align: center;"><strong>다섯번째 PW</strong></td>
<td style="text-align: center;"><strong>여섯번째 PW</strong></td>
<td colspan="11" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(Password “000000”)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **3C** | **06** | **00** | **00** | **00** | **00** | **00** | **00** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

2.  BT_NEW_APP_PASSWD_IND(0x3D) (인슐린펌프 -\> 앱)

- 변경된 신규 Password정보를 전달한다. (인슐린펌프-\>앱)

- msg_type: 0x3D

- Data length: 6.

| **구분**            | **Data Length** | **Description**          |
|---------------------|:---------------:|--------------------------|
| 1<sup>st</sup> byte |        1        | Password 첫번째 바이트   |
| 2<sup>nd</sup> byte |        1        | Password 두번째 바이트   |
| 3<sup>rd</sup> byte |        1        | Password 세번째 바이트   |
| 4<sup>th</sup> byte |        1        | Password 네번째 바이트   |
| 5<sup>th</sup> byte |        1        | Password 다섯번째 바이트 |
| 6<sup>th</sup> byte |        1        | Password 여섯번째 바이트 |

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>3D</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td style="text-align: center;"><strong>첫번째 PW</strong></td>
<td style="text-align: center;"><strong>두번째 PW</strong></td>
<td style="text-align: center;"><strong>세번째 PW</strong></td>
<td style="text-align: center;"><strong>네번째 PW</strong></td>
<td style="text-align: center;"><strong>다섯번째 PW</strong></td>
<td style="text-align: center;"><strong>여섯번째 PW</strong></td>
<td colspan="11" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(Password “123456”)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **3D** | **06** | **01** | **02** | **03** | **04** | **05** | **06** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |

3.  BT_PRS_APP_PASSWD_REQ(0x41) (앱 -\> 인슐린펌프)

- 기존 Password정보를 전달한다.

- msg_type: 0x41

- Data length: 0

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
<col style="width: 5%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>41</strong></td>
<td style="text-align: center;"><strong>00</strong></td>
<td colspan="17" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

4.  BT_NEW_APP_PASSWD_IND(0x42) (인슐린펌프 -\> 앱)

- 변경된 신규 Password정보를 전달한다.

- msg_type: 0x42

- Data length: 6

| **구분**            | **Data Length** | **Description**          |
|---------------------|:---------------:|--------------------------|
| 1<sup>st</sup> byte |        1        | Password 첫번째 바이트   |
| 2<sup>nd</sup> byte |        1        | Password 두번째 바이트   |
| 3<sup>rd</sup> byte |        1        | Password 세번째 바이트   |
| 4<sup>th</sup> byte |        1        | Password 네번째 바이트   |
| 5<sup>th</sup> byte |        1        | Password 다섯번째 바이트 |
| 6<sup>th</sup> byte |        1        | Password 여섯번째 바이트 |

- **Packet Structure**

<table>
<colgroup>
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 6%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
<col style="width: 4%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;">0</th>
<th style="text-align: center;">1</th>
<th style="text-align: center;">2</th>
<th style="text-align: center;">3</th>
<th style="text-align: center;">4</th>
<th style="text-align: center;">5</th>
<th style="text-align: center;">6</th>
<th style="text-align: center;">7</th>
<th style="text-align: center;">8</th>
<th style="text-align: center;">9</th>
<th style="text-align: center;">10</th>
<th style="text-align: center;">11</th>
<th style="text-align: center;">12</th>
<th style="text-align: center;">13</th>
<th style="text-align: center;">14</th>
<th style="text-align: center;">15</th>
<th style="text-align: center;">16</th>
<th style="text-align: center;">17</th>
<th style="text-align: center;">18</th>
<th style="text-align: center;">19</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>EF</strong></td>
<td style="text-align: center;"><strong>42</strong></td>
<td style="text-align: center;"><strong>06</strong></td>
<td style="text-align: center;"><strong>첫번째 PW</strong></td>
<td style="text-align: center;"><strong>두번째 PW</strong></td>
<td style="text-align: center;"><strong>세번째 PW</strong></td>
<td style="text-align: center;"><strong>네번째 PW</strong></td>
<td style="text-align: center;"><strong>다섯번째 PW</strong></td>
<td style="text-align: center;"><strong>여섯번째 PW</strong></td>
<td colspan="11" style="text-align: center;"><strong>사용 안함 Pad(0x00)</strong></td>
</tr>
</tbody>
</table>

- 예제(Password “123456”)

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **EF** | **42** | **06** | **01** | **02** | **03** | **04** | **05** | **06** | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |
