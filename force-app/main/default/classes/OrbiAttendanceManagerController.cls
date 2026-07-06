/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : OrbiAttendanceManagerController
 * Author          : Pankaj Saini
 * Created Date    : Mar 14, 2026
 * Last Modified By: Pankaj Saini
 * Last Modified On: Mar 14, 2026
 * Description     : Controller for Attendance Dashboard - Fetches and calculates 
 *                   attendance data for a specific user based on Author__c field
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Mar 14, 2026  │ Pankaj Saini   │ Initial version with authorId parameter
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class OrbiAttendanceManagerController {
    
	@AuraEnabled
	public static DashboardDataWrapper getAttendanceDashboardData(String authorId) {
		DashboardDataWrapper dashboardData = new DashboardDataWrapper();
		try {
			dashboardData.authorId = authorId;
			dashboardData.authorInfo = getAuthorInfo(authorId);
			dashboardData.timeSheet = getTimeSheet(authorId,dashboardData.authorInfo.totalWorkingTime);
			dashboardData.today = getTodayStatistic(authorId,dashboardData.authorInfo.totalWorkingTime);
			dashboardData.thisWeek = getThisWeekStatistic(authorId,dashboardData.authorInfo.totalWorkingTime,dashboardData.authorInfo.weeklyWorkingDays);
			dashboardData.thisMonth = getThisMonthStatistic(authorId,dashboardData.authorInfo.totalWorkingTime,dashboardData.authorInfo.weeklyWorkingDays);
			dashboardData.remaining = getRemainingThisMonthStatistic(authorId,dashboardData.authorInfo.totalWorkingTime,dashboardData.authorInfo.weeklyWorkingDays);
			dashboardData.attendanceRecords = getAttendanceRecords(authorId);
			dashboardData.dashboardSummer = getDashboardSummaryData(authorId ,'THIS_WEEK');
			dashboardData.AuthorLeaveDetail = getAuthorLeaveDetail(authorId,'LAST_QUARTER',dashboardData.authorInfo.leavesAllowed);
			dashboardData.lastUpdated = DateTime.now();

			System.debug('Dashboard Data: ' + dashboardData);
			return dashboardData;

		} catch (Exception e) {
			System.debug('Error: ' + e.getMessage());
			return null;
		}
	}

	public static authorInfoWrapper getAuthorInfo(String authorId) {
		List<Author__c> authorList = [SELECT Id, Name, Reporting_Time__c, Total_Working_Time__c, Leaves_Allowed__c, Weekly_Working_Days__c  FROM Author__c WHERE Id = :authorId];
		if(authorList.size() > 0){
			authorInfoWrapper authorInfo = new authorInfoWrapper();	
			authorInfo.authorId = authorList[0].Id;
			authorInfo.authorName = authorList[0].Name;		
			authorInfo.reportingTime = authorList[0].Reporting_Time__c;	
			authorInfo.totalWorkingTime = authorList[0].Total_Working_Time__c;	
			authorInfo.leavesAllowed = authorList[0].Leaves_Allowed__c;
			authorInfo.weeklyWorkingDays = authorList[0].Weekly_Working_Days__c;

			System.debug('authorInfo: ' + authorInfo);
			return authorInfo;
		}
		return null;
	}

	public static TimeSheetWrapper getTimeSheet(String authorId , Decimal expectedDailyHours) {
		TimeSheetWrapper timeSheet = new TimeSheetWrapper();

		try {
			Date todayDate = Date.today();
			
			List<Attendance_Log__c> attendanceLogs = [
				SELECT Id, login_date_time__c, Logout_Date_Time__c,
					Total_Time__c, Login_Today__c, isLogOff__c, working_from__c
				FROM Attendance_Log__c
				WHERE Author__c = :authorId
				AND login_date_time__c >= :DateTime.newInstance(todayDate, Time.newInstance(0, 0, 0, 0))
				AND login_date_time__c < :DateTime.newInstance(todayDate.addDays(1), Time.newInstance(0, 0, 0, 0))
				ORDER BY login_date_time__c DESC
				LIMIT 1
			];

			

			if(!attendanceLogs.isEmpty()){
				Attendance_Log__c log = attendanceLogs[0];

				System.debug('Log Record: ' + log);

				Decimal actualHours;

				if(log.isLogOff__c){
					actualHours = log.Total_Time__c != null ? log.Total_Time__c : 0;
					timeSheet.logoutTime = log.Logout_Date_Time__c;
				}
				else{
					actualHours = OrbiAttendanceManagerControllerUtility.getTotalWorkingHours(log.login_date_time__c);
					timeSheet.logoutTime = Null;
				}
				timeSheet.isLogInToday = true;
				timeSheet.loginTime = log.login_date_time__c;
				timeSheet.actualHours = actualHours.setScale(2);
				timeSheet.expectedHours = expectedDailyHours;
				timeSheet.workingFrom = log.working_from__c;
				timeSheet.isLoggedOut = log.isLogOff__c;
				timeSheet.workingPercentage = OrbiAttendanceManagerControllerUtility.getWorkingPercentage(timeSheet.actualHours,timeSheet.expectedHours);
			}else {
					timeSheet.isLogInToday = false;
					timeSheet.loginTime = null;
					timeSheet.logoutTime = null;
					timeSheet.actualHours = null;
					timeSheet.expectedHours = null;
					timeSheet.workingFrom = null;
					timeSheet.isLoggedOut = null;
					timeSheet.workingPercentage = null;
			}

			System.debug('timeSheet: ' + timeSheet);
			return timeSheet;


		} catch (Exception e) {
			System.debug('Error: ' + e.getMessage());
			throw e;
		}
	}

	public static statisticWrapper getTodayStatistic(String authorId, Decimal expectedDailyHours) {
		try {

			statisticWrapper statistic = new statisticWrapper();
			statistic.period = 'TODAY';

			Date todayDate = Date.today();
			DateTime startOfDay = DateTime.newInstance(todayDate, Time.newInstance(0, 0, 0, 0));
			DateTime endOfDay = DateTime.newInstance(todayDate.addDays(1), Time.newInstance(0, 0, 0, 0));

			List<Attendance_Log__c> attendanceLogs = [
				SELECT login_date_time__c, Total_Time__c, isLogOff__c
				FROM Attendance_Log__c
				WHERE Author__c = :authorId
				AND login_date_time__c >= :startOfDay
				AND login_date_time__c < :endOfDay
				ORDER BY login_date_time__c DESC
				LIMIT 1
			];

			if(!attendanceLogs.isEmpty()){
				Attendance_Log__c log = attendanceLogs[0];
				Decimal actualHours;

				if(log.isLogOff__c){
					actualHours = log.Total_Time__c != null ? log.Total_Time__c : 0;
				} else{
					actualHours = OrbiAttendanceManagerControllerUtility.getTotalWorkingHours(log.login_date_time__c);
				}

				statistic.actualHours = actualHours.setScale(2);

				Integer holidayCount = OrbiAttendanceManagerControllerUtility.getHolidays(statistic.period).size();

				statistic.expectedHours = (holidayCount > 0) ? 0 : expectedDailyHours;

				statistic.totalPresent = 1;

			} else{
				statistic.totalPresent = 0;
			}

			statistic.workingPercentage = OrbiAttendanceManagerControllerUtility.getWorkingPercentage(statistic.actualHours,statistic.expectedHours);

			System.debug('TodayStatistic: ' + statistic);

			return statistic;

		} catch (Exception e) {
			System.debug('TODAY ERROR: ' + e.getMessage());
			throw e;
		}
	}

	public static statisticWrapper getThisWeekStatistic(String authorId, Decimal expectedDailyHours , Decimal weeklyWorkingDays) {
		try {

			statisticWrapper statistic = new statisticWrapper();
			statistic.period = 'THIS WEEK';

			Decimal totalHours = 0;

			AggregateResult result = [
				SELECT SUM(Total_Time__c) totalHours
				FROM Attendance_Log__c
				WHERE Author__c = :authorId
				AND login_date_time__c = THIS_WEEK
				AND isLogOff__c = true
			];

			if(result != null){
				totalHours = (Decimal) result.get('totalHours');
				totalHours = totalHours == null ? 0 : totalHours;
			}

			List<Attendance_Log__c> activeLog = [
				SELECT login_date_time__c
				FROM Attendance_Log__c
				WHERE Author__c = :authorId
				AND isLogOff__c = false
				AND login_date_time__c = THIS_WEEK
				ORDER BY login_date_time__c DESC
				LIMIT 1
			];

			if(!activeLog.isEmpty()){
				Decimal liveHours = OrbiAttendanceManagerControllerUtility.getTotalWorkingHours(activeLog[0].login_date_time__c);

				totalHours += liveHours;
			}

			List<Attendance_Log__c> distinctDays = [
				SELECT login_date_time__c
				FROM Attendance_Log__c
				WHERE Author__c = :authorId
				AND login_date_time__c = THIS_WEEK
			];

			Set<Date> uniqueDates = new Set<Date>();
			for(Attendance_Log__c log : distinctDays) {
				uniqueDates.add(log.login_date_time__c.date());
			}
			Integer presentDays = uniqueDates.size();

			statistic.actualHours = totalHours.setScale(2);

			Integer holidayCount = OrbiAttendanceManagerControllerUtility.getHolidays(statistic.period).size();

			if(holidayCount > 0) {
				statistic.expectedHours = expectedDailyHours * (weeklyWorkingDays - holidayCount);
				statistic.workingDays = weeklyWorkingDays - holidayCount;
			}
			else {
				statistic.expectedHours = expectedDailyHours * weeklyWorkingDays;
				statistic.workingDays = weeklyWorkingDays;
			}

			statistic.totalPresent = presentDays;

			statistic.workingPercentage =OrbiAttendanceManagerControllerUtility.getWorkingPercentage(statistic.actualHours,statistic.expectedHours);


			System.debug('ThisWeekStatistic: ' + statistic);
			return statistic;

		} catch (Exception e) {
			System.debug('THIS WEEK ERROR: ' + e.getMessage());
			throw e;
		}
	}

	public static statisticWrapper getThisMonthStatistic(String authorId,Decimal expectedDailyHours,Decimal weeklyWorkingDays) {
		try {

			statisticWrapper statistic = new statisticWrapper();
			statistic.period = 'THIS MONTH';

			Decimal totalHours = 0;

			AggregateResult result = [
				SELECT SUM(Total_Time__c) totalHours
				FROM Attendance_Log__c
				WHERE Author__c = :authorId
				AND login_date_time__c = THIS_MONTH
				AND isLogOff__c = true
			];

			if(result != null){
				totalHours = (Decimal) result.get('totalHours');
				totalHours = totalHours == null ? 0 : totalHours;
			}

			List<Attendance_Log__c> activeLog = [
				SELECT login_date_time__c
				FROM Attendance_Log__c
				WHERE Author__c = :authorId
				AND isLogOff__c = false
				AND login_date_time__c = THIS_MONTH
				ORDER BY login_date_time__c DESC
				LIMIT 1
			];

			if(!activeLog.isEmpty()){

				Decimal liveHours = OrbiAttendanceManagerControllerUtility.getTotalWorkingHours(activeLog[0].login_date_time__c);

				totalHours += liveHours;
			}
			List<Attendance_Log__c> distinctDays = [
				SELECT login_date_time__c
				FROM Attendance_Log__c
				WHERE Author__c = :authorId
				AND login_date_time__c = THIS_MONTH
			];

			Set<Date> uniqueDates = new Set<Date>();
			for(Attendance_Log__c log : distinctDays) {
				uniqueDates.add(log.login_date_time__c.date());
			}
			Integer presentDays = uniqueDates.size();

			statistic.actualHours = totalHours.setScale(2);
			Integer workingDays = OrbiAttendanceManagerControllerUtility.getWorkingDaysInMonth(weeklyWorkingDays);
			statistic.workingDays = workingDays;
			statistic.expectedHours = expectedDailyHours * workingDays;
			statistic.totalPresent = presentDays;

			statistic.workingPercentage = OrbiAttendanceManagerControllerUtility.getWorkingPercentage(statistic.actualHours,statistic.expectedHours);


			System.debug('This Week Statistic: ' + statistic);
			return statistic;

		} catch (Exception e) {
			System.debug('THIS MONTH ERROR: ' + e.getMessage());
			throw e;
		}
	}

	public static statisticWrapper getRemainingThisMonthStatistic(String authorId,Decimal expectedDailyHours,Decimal weeklyWorkingDays) {

		statisticWrapper statistic = new statisticWrapper();
		statistic.period = 'REMAINING THIS MONTH';

		statisticWrapper monthStat =getThisMonthStatistic(authorId, expectedDailyHours, weeklyWorkingDays);

		Integer totalWorkingDays =
			OrbiAttendanceManagerControllerUtility.getWorkingDaysInMonth(weeklyWorkingDays);

		Integer remainingDays = totalWorkingDays - monthStat.totalPresent;

		if(remainingDays < 0) {
			remainingDays = 0;
		}

		Decimal remainingHours = monthStat.expectedHours - monthStat.actualHours;

		statistic.actualHours =
			remainingHours > 0 ? remainingHours.setScale(2) : 0;

		statistic.expectedHours = monthStat.expectedHours;
		statistic.totalPresent = remainingDays;

		statistic.workingDays = totalWorkingDays;

		statistic.workingPercentage = monthStat.workingPercentage;


		System.debug('Remaining This Month Statistic: ' + statistic);
		return statistic;
	}

	public static List<AttendanceRecordWrapper> getAttendanceRecords(String authorId) {

		List<AttendanceRecordWrapper> records = new List<AttendanceRecordWrapper>();

		try {
			Date todayDate = Date.today();
			
			List<Attendance_Log__c> attendanceLogs = [
				SELECT login_date_time__c,
					Logout_Date_Time__c,
					Total_Time__c,
					working_from__c,
					isLogOff__c,Status__c 
				FROM Attendance_Log__c
				WHERE Author__c = :authorId
				AND login_date_time__c = THIS_MONTH
				AND login_date_time__c < :DateTime.newInstance(todayDate, Time.newInstance(0, 0, 0, 0))
				ORDER BY login_date_time__c DESC
			];

			Integer rowNumber = 1;

			for(Attendance_Log__c log : attendanceLogs){
				AttendanceRecordWrapper wrapper = new AttendanceRecordWrapper();
			
				wrapper.rowNumber = rowNumber;
			
				if(log.login_date_time__c != null){
					wrapper.logInDate = (log.login_date_time__c != null) ? log.login_date_time__c.date() : null;
					wrapper.logInTime = (log.login_date_time__c != null) ? log.login_date_time__c.time() : null;
				}
			
				if(log.Logout_Date_Time__c != null){
					wrapper.logOffDate = (log.Logout_Date_Time__c != null) ? log.Logout_Date_Time__c.date() : null;
					wrapper.logOffTime = (log.Logout_Date_Time__c != null) ? log.Logout_Date_Time__c.time() : null;
				}
			
				if(log.isLogOff__c){
					wrapper.productionHours = log.Total_Time__c;
				}
				else{
					wrapper.productionHours = OrbiAttendanceManagerControllerUtility.getTotalWorkingHours(log.login_date_time__c);
				}
			
				wrapper.status = log.Status__c;
				wrapper.workingFrom = log.working_from__c;
			
				records.add(wrapper);
				rowNumber++;
			}

			System.debug('Attendance Records: ' + records);
			return records;

		} catch (Exception e) {

			System.debug('ATTENDANCE RECORD ERROR: ' + e.getMessage());
			throw e;
		}
	}

	@AuraEnabled
	public static DashboardDataSummerWrapper getDashboardSummaryData(Id authorId, String period) {
		DashboardDataSummerWrapper dashboardSummery = new DashboardDataSummerWrapper();
		try {
			dashboardSummery.period = period;
			dashboardSummery.authorId = authorId;
			dashboardSummery.authorInfo = getAuthorInfo(authorId);
			dashboardSummery.totalDaysWorked = OrbiAttendanceManagerControllerUtility.getAuthorTotalDaysWorked(authorId , period);
			dashboardSummery.totalAbsentCount = OrbiAttendanceManagerControllerUtility.getAuthorAbsentCount(authorId , period);
			dashboardSummery.totalLateCount = OrbiAttendanceManagerControllerUtility.getAuthorLateCount(authorId , period);
			dashboardSummery.totalPresentCount = OrbiAttendanceManagerControllerUtility.getAuthorPresentCount(authorId , period);
			dashboardSummery.totalWFHCount = OrbiAttendanceManagerControllerUtility.getAuthorWFHCount(authorId , period);
			dashboardSummery.totalOfficeCount = OrbiAttendanceManagerControllerUtility.getAuthorOfficeCount(authorId , period);


		}catch(Exception e) {
			System.debug('DASHBOARD DashboardDataSummerWrapper: ' + e.getMessage());
			throw e;
		}
		return dashboardSummery;
	}

	@AuraEnabled
	public static AuthorLeaveDetailWrapper getAuthorLeaveDetail(Id authorId,String period, Decimal totalLeaves) {
		
		AuthorLeaveDetailWrapper leaveDetail = new AuthorLeaveDetailWrapper();

		try {
			leaveDetail.period = period;
			leaveDetail.authorInfo = getAuthorInfo(authorId);

			List<Leave_Detail_Line_Item__c> leaveDetailLineItems = OrbiAttendanceManagerControllerUtility.getLeaveDetailLineItem(authorId, period);

			Decimal usedLeaves = 0;

			for (Leave_Detail_Line_Item__c ldli : leaveDetailLineItems) {
				usedLeaves += (ldli.duration__c == 'Half Day') ? 0.5 : 1;

				leaveDetailWrapper leaveDetailVar = new leaveDetailWrapper();

				leaveDetailVar.dateIs     = String.valueOf(ldli.date_is__c);
				leaveDetailVar.status     = ldli.status__c;
				leaveDetailVar.duration   = String.valueOf(ldli.duration__c);
				leaveDetailVar.leaveWFH   = ldli.leave_wfh__c;
				leaveDetailVar.leaveType  = ldli.type__c;
				leaveDetailVar.LeaveDate  = String.valueOf(ldli.date__c);

				leaveDetail.leaveDetails.add(leaveDetailVar);
			}

			Decimal remaining = totalLeaves - usedLeaves;

			leaveDetail.remainingLeaves = String.valueOf(
				remaining > 0 ? remaining.setScale(2) : 0
			);

		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
		
		return leaveDetail;
	}

	public class DashboardDataWrapper {
		@AuraEnabled public String authorId { get; set; }
		@AuraEnabled public authorInfoWrapper authorInfo { get; set; }
		@AuraEnabled public TimeSheetWrapper timeSheet { get; set; }
		@AuraEnabled public statisticWrapper today { get; set; }
        @AuraEnabled public statisticWrapper thisWeek { get; set; }
        @AuraEnabled public statisticWrapper thisMonth { get; set; }
        @AuraEnabled public statisticWrapper remaining { get; set; }
		@AuraEnabled public List<AttendanceRecordWrapper> attendanceRecords { get; set; }
		@AuraEnabled public DashboardDataSummerWrapper dashboardSummer { get; set; }
		@AuraEnabled public DateTime lastUpdated { get; set; }
		@AuraEnabled public AuthorLeaveDetailWrapper AuthorLeaveDetail { get;set; }


		public DashboardDataWrapper() {
            this.today = new statisticWrapper();
            this.thisWeek = new statisticWrapper();
            this.thisMonth = new statisticWrapper();
            this.remaining = new statisticWrapper();
            this.attendanceRecords = new List<AttendanceRecordWrapper>();
			this.dashboardSummer = new DashboardDataSummerWrapper();
			this.AuthorLeaveDetail = new AuthorLeaveDetailWrapper();
			this.lastUpdated = DateTime.now();
        }
	}

	public class authorInfoWrapper {
        @AuraEnabled public String authorId { get; set; }
        @AuraEnabled public String authorName { get; set; }
        @AuraEnabled public Time reportingTime { get; set; }
		@AuraEnabled public Decimal totalWorkingTime { get; set; }
		@AuraEnabled public Decimal leavesAllowed {get;set;}
		@AuraEnabled public Decimal weeklyWorkingDays {get;set;}		
	}

	public class TimeSheetWrapper {
		@AuraEnabled public Boolean isLogInToday { get; set; }
        @AuraEnabled public DateTime loginTime { get; set; }
        @AuraEnabled public DateTime logoutTime { get; set; }
        @AuraEnabled public Decimal actualHours { get; set; }
        @AuraEnabled public Decimal expectedHours { get; set; }
        @AuraEnabled public String workingFrom { get; set; }
        @AuraEnabled public Boolean isLoggedOut { get; set; }
		@AuraEnabled public Decimal workingPercentage { get; set; }
	}

	public class AttendanceRecordWrapper {
		@AuraEnabled public Integer rowNumber { get; set; }
		@AuraEnabled public Date logInDate { get; set; }
		@AuraEnabled public Date logOffDate { get; set; }
		@AuraEnabled public Time logInTime { get; set; }
		@AuraEnabled public Time logOffTime { get; set; }
		@AuraEnabled public Decimal productionHours { get; set; }
		@AuraEnabled public String workingFrom { get; set; }
		@AuraEnabled public String status { get; set; }
	}

	public class statisticWrapper {
		@AuraEnabled public String period { get; set; }
		@AuraEnabled public Decimal actualHours { get; set; }
        @AuraEnabled public Decimal expectedHours { get; set; }
		@AuraEnabled public Decimal workingPercentage { get; set; }
		@AuraEnabled public Integer totalPresent { get; set; }
		@AuraEnabled public Decimal workingDays { get; set; }
	}

	public class DashboardDataSummerWrapper {
		@AuraEnabled public String period { get; set; }
		@AuraEnabled public String authorId { get; set; }
		@AuraEnabled public authorInfoWrapper authorInfo { get; set;}
		@AuraEnabled public Integer totalDaysWorked { get; set; }
		@AuraEnabled public Integer totalLateCount { get; set; }
		@AuraEnabled public Integer totalAbsentCount { get; set; }
		@AuraEnabled public Integer totalPresentCount {get; set;}
		@AuraEnabled public Integer totalWFHCount {get; set;}
		@AuraEnabled public Integer totalOfficeCount {get; set;}
	}

	public class AuthorLeaveDetailWrapper {
		@AuraEnabled public String period { get; set; }
		@AuraEnabled public String remainingLeaves { get; set; }
		@AuraEnabled public authorInfoWrapper authorInfo { get; set;}
		@AuraEnabled public List<leaveDetailWrapper> leaveDetails { get; set; }

		public AuthorLeaveDetailWrapper(){
			leaveDetails = new List<leaveDetailWrapper>();
		}
	}

	public class leaveDetailWrapper {
		@AuraEnabled public String dateIs { get; set; }
		@AuraEnabled public String status { get; set; }
		@AuraEnabled public String duration { get; set; }
		@AuraEnabled public String leaveWFH { get; set; }
		@AuraEnabled public String leaveType { get; set; }
		@AuraEnabled public String LeaveDate { get; set; }
		
		public leaveDetailWrapper() {}
	}
}