public with sharing class OrbiAttendanceManagerControllerUtility {

    public static Decimal getTotalWorkingHours(DateTime loginDateTime) {

        if(loginDateTime == null) return 0;
        Decimal hours = (DateTime.now().getTime() - loginDateTime.getTime()) / 3600000.0;
        return hours.setScale(2);

    }

    public static Decimal getWorkingPercentage(Decimal actualHours, Decimal expectedHours) {

        if(actualHours == null){
            actualHours = 0;
        }
        if(expectedHours == null || expectedHours == 0){
            return 0;
        }
        Decimal workingPercentage = (actualHours / expectedHours) * 100;
        return workingPercentage.setScale(2);

    }

    public static List<Holiday> getHolidays(String criteriaType){
        List<Holiday> holidayList = new List<Holiday>();

        switch on criteriaType {
            when 'TODAY' {
                holidayList = [SELECT Id, Name, ActivityDate , IsAllDay FROM Holiday where ActivityDate =TODAY];
            }	
            when 'THIS WEEK' {
                holidayList = [SELECT Id, Name, ActivityDate , IsAllDay FROM Holiday where ActivityDate =THIS_WEEK];
            }
            when 'THIS MONTH' {	
                holidayList = [SELECT Id, Name, ActivityDate , IsAllDay FROM Holiday where ActivityDate =THIS_MONTH ];
            }
            when 'THIS QUARTER' {
                holidayList = [SELECT Id, Name, ActivityDate , IsAllDay FROM Holiday where ActivityDate =THIS_QUARTER];
            }
            when 'THIS YEAR' {
                holidayList = [SELECT Id, Name, ActivityDate , IsAllDay FROM Holiday where ActivityDate =THIS_YEAR];
            }
            when else {
                holidayList = null;
            }
        }

        return holidayList;
    }

    public static Integer getAuthorTotalDaysWorked(Id author, String period) {
        try {
            period = period.trim().replace(' ', '_').toUpperCase();
            
            Set<String> allowedPeriods = new Set<String>{
                'THIS_WEEK', 'THIS_MONTH', 'THIS_QUARTER', 'THIS_YEAR'
            };
            
            if (!allowedPeriods.contains(period)) {
                throw new AuraHandledException('Invalid period: ' + period);
            }
            
            String query = 'SELECT COUNT(Id) total ' +
                        'FROM Attendance_Log__c ' +
                        'WHERE Author__c = :author ' +
                        'AND login_date_time__c = ' + period;
            
            AggregateResult[] results = Database.query(query);
            return (Integer) results[0].get('total');
        } catch (Exception e) {
            System.debug('Error in getAuthorTotalDaysWorked: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static Integer getAuthorAbsentCount(Id author, String period) {
        try {
            period = period.trim().replace(' ', '_').toUpperCase();
            
            Set<String> allowedPeriods = new Set<String>{
                'THIS_WEEK', 'THIS_MONTH', 'THIS_QUARTER', 'THIS_YEAR'
            };
            
            if (!allowedPeriods.contains(period)) {
                throw new AuraHandledException('Invalid period: ' + period);
            }
            
            Author__c auth = [SELECT Weekly_Working_Days__c FROM Author__c WHERE Id = :author LIMIT 1];
            Decimal weeklyWorkingDays = auth.Weekly_Working_Days__c;

            Date today = Date.today();
            Date startDate;

            switch on period {
                when 'THIS_WEEK' {
                    startDate = today.toStartOfWeek();
                }
                when 'THIS_MONTH' {
                    startDate = Date.newInstance(today.year(), today.month(), 1);
                }
                when 'THIS_QUARTER' {
                    Integer quarter = (today.month() - 1) / 3 + 1;
                    if (quarter == 1) {
                        startDate = Date.newInstance(today.year(), 1, 1);
                    } else if (quarter == 2) {
                        startDate = Date.newInstance(today.year(), 4, 1);
                    } else if (quarter == 3) {
                        startDate = Date.newInstance(today.year(), 7, 1);
                    } else {
                        startDate = Date.newInstance(today.year(), 10, 1);
                    }
                }
                when 'THIS_YEAR' {
                    startDate = Date.newInstance(today.year(), 1, 1);
                }
            }

            Integer workingDays = getWorkingDaysBetween(startDate, today, weeklyWorkingDays);

            Date tomorrow = today.addDays(1);
            String query = 'SELECT COUNT(Id) total FROM Attendance_Log__c WHERE Author__c = :author AND login_date_time__c >= :startDate AND login_date_time__c < :tomorrow';
            AggregateResult[] results = Database.query(query);
            Integer daysWorked = (Integer) results[0].get('total');

            Integer absentCount = workingDays - daysWorked;
            return absentCount > 0 ? absentCount : 0;

        } catch (Exception e) {
            System.debug('Error in getAuthorAbsentCount: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Integer getWorkingDaysBetween(Date startDate, Date endDate, Decimal weeklyWorkingDays) {
        Integer workingDays = 0;
        Set<Date> holidayDates = new Set<Date>();
        List<Holiday> holidays = [SELECT ActivityDate FROM Holiday WHERE ActivityDate >= :startDate AND ActivityDate <= :endDate];
        for (Holiday h : holidays) {
            holidayDates.add(h.ActivityDate);
        }

        for (Date d = startDate; d <= endDate; d = d.addDays(1)) {
            Integer dayOfWeek = d.toStartOfWeek().daysBetween(d) + 1;

            Boolean isWeekend = false;

            if (weeklyWorkingDays == 5) {
                isWeekend = (dayOfWeek == 1 || dayOfWeek == 7);
            } else if (weeklyWorkingDays == 6) {
                isWeekend = (dayOfWeek == 1);
            }

            if (!isWeekend && !holidayDates.contains(d)) {
                workingDays++;
            }
        }

        return workingDays;
    }

    public static Integer getWorkingDaysInMonth(Decimal weeklyWorkingDays) {
        Date today = Date.today();
        Integer year = today.year();
        Integer month = today.month();

        Date startDate = Date.newInstance(year, month, 1);
        Date endDate = startDate.addMonths(1).addDays(-1);

        Integer workingDays = 0;
        Set<Date> holidayDates = new Set<Date>();
        for(Holiday h : getHolidays('THIS MONTH')) {
            if(h != null) holidayDates.add(h.ActivityDate);
        }

        for(Date d = startDate; d <= endDate; d = d.addDays(1)) {

            Integer dayOfWeek = d.toStartOfWeek().daysBetween(d) + 1;

            Boolean isWeekend = false;


            if(weeklyWorkingDays == 5) {
                isWeekend = (dayOfWeek == 1 || dayOfWeek == 7);
            }
            else if(weeklyWorkingDays == 6) {
                isWeekend = (dayOfWeek == 1);
            }

            if(!isWeekend && !holidayDates.contains(d)) {
                workingDays++;
            }
        }

        return workingDays;
    }

    public static Integer getWorkingDaysInWeek(Decimal weeklyWorkingDays) {
        Date today = Date.today();
        Date startOfWeek = today.toStartOfWeek();
        Date endOfWeek = startOfWeek.addDays(6);

        Integer workingDays = 0;
        Set<Date> holidayDates = new Set<Date>();
        for(Holiday h : getHolidays('THIS WEEK')) {
            if(h != null) holidayDates.add(h.ActivityDate);
        }

        for(Date d = startOfWeek; d <= endOfWeek; d = d.addDays(1)) {
            Integer dayOfWeek = d.toStartOfWeek().daysBetween(d) + 1;

            Boolean isWeekend = false;

            if(weeklyWorkingDays == 5) {
                isWeekend = (dayOfWeek == 1 || dayOfWeek == 7);
            } else if(weeklyWorkingDays == 6) {
                isWeekend = (dayOfWeek == 1);
            }

            if(!isWeekend && !holidayDates.contains(d)) {
                workingDays++;
            }
        }

        return workingDays;
    }

    public static Integer getWorkingDaysInQuarter(Decimal weeklyWorkingDays) {
        Date today = Date.today();
        Integer quarter = (today.month() - 1) / 3 + 1;

        Date startOfQuarter;
        Date endOfQuarter;

        if(quarter == 1) {
            startOfQuarter = Date.newInstance(today.year(), 1, 1);
            endOfQuarter = Date.newInstance(today.year(), 3, 31);
        } else if(quarter == 2) {
            startOfQuarter = Date.newInstance(today.year(), 4, 1);
            endOfQuarter = Date.newInstance(today.year(), 6, 30);
        } else if(quarter == 3) {
            startOfQuarter = Date.newInstance(today.year(), 7, 1);
            endOfQuarter = Date.newInstance(today.year(), 9, 30);
        } else {
            startOfQuarter = Date.newInstance(today.year(), 10, 1);
            endOfQuarter = Date.newInstance(today.year(), 12, 31);
        }

        Integer workingDays = 0;
        Set<Date> holidayDates = new Set<Date>();
        for(Holiday h : getHolidays('THIS QUARTER')) {
            if(h != null) holidayDates.add(h.ActivityDate);
        }

        for(Date d = startOfQuarter; d <= endOfQuarter; d = d.addDays(1)) {
            Integer dayOfWeek = d.toStartOfWeek().daysBetween(d) + 1;

            Boolean isWeekend = false;

            if(weeklyWorkingDays == 5) {
                isWeekend = (dayOfWeek == 1 || dayOfWeek == 7);
            } else if(weeklyWorkingDays == 6) {
                isWeekend = (dayOfWeek == 1);
            }

            if(!isWeekend && !holidayDates.contains(d)) {
                workingDays++;
            }
        }

        return workingDays;
    }

    public static Integer getWorkingDaysInYear(Decimal weeklyWorkingDays) {
        Date today = Date.today();
        Date startOfYear = Date.newInstance(today.year(), 1, 1);
        Date endOfYear = Date.newInstance(today.year(), 12, 31);

        Integer workingDays = 0;
        Set<Date> holidayDates = new Set<Date>();
        for(Holiday h : getHolidays('THIS YEAR')) {
            if(h != null) holidayDates.add(h.ActivityDate);
        }

        for(Date d = startOfYear; d <= endOfYear; d = d.addDays(1)) {
            Integer dayOfWeek = d.toStartOfWeek().daysBetween(d) + 1;

            Boolean isWeekend = false;

            if(weeklyWorkingDays == 5) {
                isWeekend = (dayOfWeek == 1 || dayOfWeek == 7);
            } else if(weeklyWorkingDays == 6) {
                isWeekend = (dayOfWeek == 1);
            }

            if(!isWeekend && !holidayDates.contains(d)) {
                workingDays++;
            }
        }

        return workingDays;
    }
    
    public static Integer getAuthorLateCount(Id author, String period) {
        try {
            period = period.trim().replace(' ', '_').toUpperCase();

            Set<String> allowedPeriods = new Set<String>{
                'THIS_WEEK', 'THIS_MONTH', 'THIS_QUARTER', 'THIS_YEAR'
            };

            if (!allowedPeriods.contains(period)) {
                throw new AuraHandledException('Invalid period: ' + period);
            }

            Author__c auth = [
                SELECT Reporting_Time__c 
                FROM Author__c 
                WHERE Id = :author 
                LIMIT 1
            ];

            Time reportingTime = auth.Reporting_Time__c;

            List<Attendance_Log__c> logs = Database.query(
                'SELECT login_date_time__c ' +
                'FROM Attendance_Log__c ' +
                'WHERE Author__c = :author ' +
                'AND login_date_time__c = ' + period
            );

            Integer lateCount = 0;

            for (Attendance_Log__c log : logs) {
                if (log.login_date_time__c != null &&
                    log.login_date_time__c.time() > reportingTime) {
                    lateCount++;
                }
            }

            return lateCount;

        } catch (Exception e) {
            System.debug('Error in getAuthorLateCount: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static Integer getAuthorPresentCount(Id author, String period) {
        try {
            period = period.trim().replace(' ', '_').toUpperCase();

            Set<String> allowedPeriods = new Set<String>{
                'THIS_WEEK', 'THIS_MONTH', 'THIS_QUARTER', 'THIS_YEAR'
            };

            if (!allowedPeriods.contains(period)) {
                throw new AuraHandledException('Invalid period: ' + period);
            }
            
            String query = 'SELECT COUNT(Id) total ' +
                        'FROM Attendance_Log__c ' +
                        'WHERE Author__c = :author ' +
                        'AND login_date_time__c = ' + period;
            
            AggregateResult[] results = Database.query(query);
            
            if (!results.isEmpty()) {
                return (Integer) results[0].get('total');
            }

            return 0;

        } catch (Exception e) {
            System.debug('Error in getAuthorPresentCount: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }



    public static Integer getAuthorWFHCount(Id author, String period) {

        try {
            period = period.trim().replace(' ', '_').toUpperCase();

            Set<String> allowedPeriods = new Set<String>{
                'THIS_WEEK', 'THIS_MONTH', 'THIS_QUARTER', 'THIS_YEAR'
            };

            if (!allowedPeriods.contains(period)) {
                throw new AuraHandledException('Invalid period: ' + period);
            }
            
            String query = 'SELECT COUNT(Id) total ' +
                        'FROM Attendance_Log__c ' +
                        'WHERE Author__c = :author ' +
                        'AND working_from__c = \'Home\' ' +
                        'AND login_date_time__c = ' + period;
            
            AggregateResult[] results = Database.query(query);
            
            if (!results.isEmpty()) {
                return (Integer) results[0].get('total');
            }

            return 0;

        } catch (Exception e) {
            System.debug('Error in getAuthorWFHCount: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }

    }

    
    public static Integer getAuthorOfficeCount(Id author, String period) {

        try {
            period = period.trim().replace(' ', '_').toUpperCase();

            Set<String> allowedPeriods = new Set<String>{
                'THIS_WEEK', 'THIS_MONTH', 'THIS_QUARTER', 'THIS_YEAR'
            };

            if (!allowedPeriods.contains(period)) {
                throw new AuraHandledException('Invalid period: ' + period);
            }
            
            String query = 'SELECT COUNT(Id) total ' +
                        'FROM Attendance_Log__c ' +
                        'WHERE Author__c = :author ' +
                        'AND working_from__c = \'Office\' ' +
                        'AND login_date_time__c = ' + period;
            
            AggregateResult[] results = Database.query(query);
            
            if (!results.isEmpty()) {
                return (Integer) results[0].get('total');
            }

            return 0;

        } catch (Exception e) {
            System.debug('Error in getAuthorOfficeCount: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }

    }

    public static List<Leave_Detail_Line_Item__c> getLeaveDetailLineItem(Id author, String period) {
        try {
            period = period.trim().replace(' ', '_').toUpperCase();
            Set<String> allowedPeriods = new Set<String>{
                'THIS_WEEK', 'THIS_MONTH', 'THIS_QUARTER', 'THIS_YEAR', 
                'LAST_WEEK', 'LAST_MONTH', 'LAST_QUARTER', 'LAST_YEAR'
            };

            if (!allowedPeriods.contains(period)) {
                throw new AuraHandledException('Invalid period: ' + period);
            }
            
            String query = 'SELECT Id, Name, date__c, leave_wfh__c, duration__c, status__c, type__c, date_is__c, Leave_Detail__c ' +
                        'FROM Leave_Detail_Line_Item__c ' +
                        'WHERE Author__c = :author ' +
                        'AND date__c = ' + period;

            return (List<Leave_Detail_Line_Item__c>) Database.query(query);

        } catch (Exception e) {
            System.debug('Error in getLeaveDetailLineItem: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static Decimal getRemainingLeavesOptimized(Id authorId,String period,Decimal totalLeaves) {
        try {
            period = period.trim().replace(' ', '_').toUpperCase();
            List<Leave_Detail_Line_Item__c> leaves = Database.query(
                'SELECT duration__c ' +
                'FROM Leave_Detail_Line_Item__c ' +
                'WHERE Author__c = :authorId ' +
                'AND date__c = ' + period
            );

            Decimal usedLeaves = 0;

            for (Leave_Detail_Line_Item__c l : leaves) {
                usedLeaves += (l.duration__c == 'Half Day') ? 0.5 : 1;
            }

            Decimal remaining = totalLeaves - usedLeaves;

            return remaining > 0 ? remaining.setScale(2) : 0;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}