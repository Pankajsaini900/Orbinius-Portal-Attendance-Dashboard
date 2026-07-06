import { LightningElement, api, track } from 'lwc';
import getAttendanceDashboardData from '@salesforce/apex/OrbiAttendanceManagerController.getAttendanceDashboardData';
import getDashboardSummaryData from '@salesforce/apex/OrbiAttendanceManagerController.getDashboardSummaryData';
import getAuthorLeaveDetail from '@salesforce/apex/OrbiAttendanceManagerController.getAuthorLeaveDetail';
import { loadScript } from 'lightning/platformResourceLoader';
import ChartJsLibrary from '@salesforce/resourceUrl/ChartjsLibrary';


export default class OrbiAttendanceManager extends LightningElement {
    @api authorId;
    isAuthenticated = true;

    @track hoursWorked = '0.00';
    @track progressPercentage = 0;
    @track animatedProgress = 0;
    @track showSpinner = false;
    @track todayDate = 'N/A';
    @track totalPresentThisMonth = 0;
    @track totalWorkingHours = 8;
    @track workingFrom = 'N/A';
    @track isLoggedIn = false;
    @track statusLabel = 'Logged Out';
    @track userCredentials = {};

    @track todayData = { actualHours: 0, expectedHours: 0, workingPercentage: 0, totalPresent: 0 };
    @track thisWeekData = { actualHours: 0, expectedHours: 0, workingPercentage: 0, totalPresent: 0, workingDays: 0 };
    @track thisMonthData = { actualHours: 0, expectedHours: 0, workingPercentage: 0, totalPresent: 0 };
    @track remainingData = { actualHours: 0, expectedHours: 0, workingPercentage: 0, totalPresent: 0 };

    @track attendanceRecords = [];
    @track hasAttendanceRecords = false;

    @track dashboardSummary = {
        totalPresentCount: 0,
        totalOfficeCount: 0,
        totalWFHCount: 0,
        totalAbsentCount: 0,
        totalLateCount: 0
    };

    @track leaveDetails = [];
    @track leavesAllowed = 0;
    @track remainingLeaves = 0;

    chart;
    @track selectedPeriod = 'THIS_WEEK';
    @track selectedLeavePeriod = 'LAST_QUARTER';

    loginDateTime;
    timerInterval;  

    circumference = 2 * Math.PI * 85;

    connectedCallback() {
        this.updatePageDataManually();
        this.todayDate = new Date().toISOString();
        console.log('this.authorId :', this.authorId);
        console.log('this.userCredentials :', JSON.stringify(this.userCredentials));
        console.log('this.isAuthenticated :', this.isAuthenticated);
        console.log('isLoggedIn: ' + this.isLoggedIn);
    }

    disconnectedCallback() {
        this.stopLiveTimer();
        if (this.chart) {
            this.chart.destroy();
            this.chart = null;
        }
    }
    
    updatePageDataManually() {
        this.showSpinner = true;
        if (this.getUserCredentialsCookie()) {
            this.isAuthenticated = false;
            this.authorId = this.userCredentials.authorId;
            this.loadAttendanceData();
        } else {
            this.showSpinner = false;
        }
    }

    getUserCredentialsCookie() {
        const cookieName = 'userCredentials';
        const cookies = document.cookie.split(';');
        let cookieValue = '';
        for (let i = 0; i < cookies.length; i++) {
            const cookie = cookies[i].trim();
            if (cookie.indexOf(cookieName) === 0) {
                cookieValue = decodeURIComponent(cookie.substring(cookieName.length + 1));
                this.userCredentials = JSON.parse(cookieValue);
                return true;
            }
        }
        return false;
    }

    loadAttendanceData() {
        this.showSpinner = true;

        getAttendanceDashboardData({ authorId: this.authorId })
            .then(result => {
                console.log('Attendance data: ', JSON.stringify(result));
                if (result) {
                    this.processTimeSheetData(result.timeSheet);
                    this.processTodayData(result.today);
                    this.processThisWeekData(result.thisWeek);
                    this.processThisMonthData(result.thisMonth);
                    this.processRemainingData(result.remaining);
                    this.processAttendanceRecords(result.attendanceRecords);
                    if (result.dashboardSummer) {
                        this.processDashboardSummary(result.dashboardSummer);
                    }

                    if (result.AuthorLeaveDetail) {
                        this.processLeaveDetail(result.AuthorLeaveDetail);
                    }

                    if (result.authorInfo) {
                        this.leavesAllowed = result.authorInfo.leavesAllowed || 0;
                    }
                    
                    setTimeout(() => this.initializeChart(), 0);
                }
                this.showSpinner = false;
            })
            .catch(error => {
                console.error('Error fetching attendance data:', error);
                this.showSpinner = false;
            });
    }

    processDashboardSummary(summary) {
        if (summary) {
            this.dashboardSummary = {
                totalPresentCount: summary.totalPresentCount || 0,
                totalOfficeCount: summary.totalOfficeCount || 0,
                totalWFHCount: summary.totalWFHCount || 0,
                totalAbsentCount: summary.totalAbsentCount || 0,
                totalLateCount: summary.totalLateCount || 0,
                period: summary.period || 'THIS_WEEK'
            };
        }
    }

    processLeaveDetail(data) {
        if (data.leaveDetails) {
            this.leaveDetails = data.leaveDetails.map(leave => ({
                ...leave,
                badgeClass: this.getLeaveStatusBadgeClass(leave.status)
            }));
        } else {
            this.leaveDetails = [];
        }
        
        this.remainingLeaves = data.remainingLeaves || 0;
        this.selectedLeavePeriod = data.period || this.selectedLeavePeriod;
    }

    initializeChart() {
        if (typeof window.Chart === 'undefined') {
            loadScript(this, ChartJsLibrary)
                .then(() => {
                    this.renderChart();
                })
                .catch(error => {
                    console.error('Error loading Chart.js:', error);
                });
        } else {
            this.renderChart();
        }
    }

    renderChart() {
        try {
            const canvas = this.template.querySelector('canvas.attendance-chart');
            
            if (!canvas) {
                console.error('Canvas element not found');
                return;
            }

            if (this.chart) {
                this.chart.destroy();
                this.chart = null;
            }

            const data = {
                    labels: ['Present', 'Office Days', 'WFH Days', 'Absent'],
                    values: [
                        this.dashboardSummary.totalPresentCount || 0,
                        this.dashboardSummary.totalOfficeCount || 0,
                        this.dashboardSummary.totalWFHCount || 0,
                        this.dashboardSummary.totalAbsentCount || 0
                    ],
                    colors: ['#FF9800', '#2196F3', '#4CAF50','#F44336']
                };

            const ctx = canvas.getContext('2d');

            this.chart = new window.Chart(ctx, {
                type: 'doughnut',
                data: {
                    labels: data.labels,
                    datasets: [{
                        data: data.values,
                        backgroundColor: data.colors,
                        borderColor: '#ffffff',
                        borderWidth: 3
                    }]
                },
                options: {
                    responsive: false, 
                    maintainAspectRatio: false,
                    cutout: '65%',
                    plugins: {
                        legend: {
                            position: 'bottom',
                            labels: {
                                usePointStyle: true,
                                generateLabels: (chart) => {
                                    const data = chart.data;
                                    return data.labels.map((label, index) => ({
                                        text: label + ': ' + data.datasets[0].data[index],
                                        fillStyle: data.datasets[0].backgroundColor[index],
                                        index: index
                                    }));
                                }
                            }
                        }
                    }
                },    
                hoverOffset: 6,
                borderRadius : 8,
                borderWidth : 1,
            });
        } catch (error) {
            console.error('Error rendering chart:', error);
        }
    }

    processTimeSheetData(timeSheet) {
        if(timeSheet && timeSheet.isLogInToday === true) {
            this.hoursWorked = timeSheet.actualHours ? timeSheet.actualHours.toFixed(2) : '0.00';

            this.progressPercentage = timeSheet.workingPercentage ? timeSheet.workingPercentage.toFixed(2) : 0;

            this.totalWorkingHours = timeSheet.expectedHours ? timeSheet.expectedHours.toFixed(2) : 8;

            this.workingFrom = timeSheet.workingFrom || 'Not Specified';

            this.isLoggedIn = !timeSheet.isLoggedOut;

            this.statusLabel = this.isLoggedIn ? 'Currently Logged In': 'Logged Out';

            this.loginDateTime = timeSheet.loginTime ? new Date(timeSheet.loginTime) : null;

            if (this.isLoggedIn && this.loginDateTime) {
                this.startLiveTimer();
            }

            this.animateProgress();

        } else {
            this.hoursWorked = '0.00';
            this.progressPercentage = '0.00';
            this.totalWorkingHours = '8.00';
            this.workingFrom = 'Not Specified';
            this.isLoggedIn = false;
            this.statusLabel = 'Logged Out';
        }
    }

    processTodayData(today) {
        if (!today) return;
        this.todayData = {
            actualHours: today.actualHours ? today.actualHours.toFixed(2) : '0.00',
            expectedHours: today.expectedHours ? today.expectedHours.toFixed(2) : '0.00',
            workingPercentage: today.workingPercentage ? today.workingPercentage.toFixed(2) : '0.00',
            totalPresent: today.totalPresent || 0
        };
    }

    processThisWeekData(thisWeek) {
        if (!thisWeek) return;
        this.thisWeekData = {
            actualHours: thisWeek.actualHours ? thisWeek.actualHours.toFixed(2) : '0.00',
            expectedHours: thisWeek.expectedHours ? thisWeek.expectedHours.toFixed(2) : '0.00',
            workingPercentage: thisWeek.workingPercentage ? thisWeek.workingPercentage.toFixed(2) : '0.00',
            totalPresent: thisWeek.totalPresent || 0,
            workingDays: thisWeek.workingDays || 0 
        };
    }

    processThisMonthData(thisMonth) {
        if (!thisMonth) return;
        this.thisMonthData = {
            actualHours: thisMonth.actualHours ? thisMonth.actualHours.toFixed(2) : '0.00',
            expectedHours: thisMonth.expectedHours ? thisMonth.expectedHours.toFixed(2) : '0.00',
            workingPercentage: thisMonth.workingPercentage ? thisMonth.workingPercentage.toFixed(2) : '0.00',
            totalPresent: thisMonth.totalPresent || 0
        };
        this.totalPresentThisMonth = thisMonth.totalPresent;
    }

    processRemainingData(remaining) {
        if (!remaining) return;
        this.remainingData = {
            actualHours: remaining.actualHours ? remaining.actualHours.toFixed(2) : '0.00',
            expectedHours: remaining.expectedHours ? remaining.expectedHours.toFixed(2) : '0.00',
            workingPercentage: remaining.workingPercentage ? remaining.workingPercentage.toFixed(2) : '0.00',
            totalPresent: remaining.totalPresent || 0
        };
    }

    processAttendanceRecords(records) {
        if (records && records.length > 0) {
            this.attendanceRecords = records.map(record => ({
                ...record,
                statusBadgeClass: this.getStatusBadgeClass(record.status),
            }));
            this.hasAttendanceRecords = true;
        } else {
            this.attendanceRecords = [];
            this.hasAttendanceRecords = false;
        }
    }

    animateProgress() {
        let currentProgress = 0;
        const targetProgress = Math.min(Number(this.progressPercentage), 100);

        const interval = setInterval(() => {
            if (currentProgress >= targetProgress) {
                clearInterval(interval);
                return;
            }
            currentProgress += 1;
            this.animatedProgress = currentProgress;
        }, 20);
    }

    handlePeriods(event) {
        this.selectedPeriod = event.target.value;
        getDashboardSummaryData({ authorId: this.authorId, period: this.selectedPeriod })
        .then(result => {
            if (result) {
                this.processDashboardSummary(result);
                this.updateChart(); 
            }
        })
        .catch(error => {
            console.error('Error fetching dashboard summary:', error);
        });
    }

    handleLeavePeriodSelect(event) {
        this.selectedLeavePeriod = event.target.value;
        this.showSpinner = true;

        getAuthorLeaveDetail({ 
            authorId: this.authorId, 
            period: this.selectedLeavePeriod, 
            totalLeaves: this.leavesAllowed 
        })
        .then(result => {
            if (result) {
                this.processLeaveDetail(result);
            }
            this.showSpinner = false;
        })
        .catch(error => {
            console.error('Error fetching Leave details:', error);
            this.showSpinner = false;
        });
    }

    updateChart() {
        if (typeof window.Chart === 'undefined') {
            loadScript(this, ChartJsLibrary)
                .then(() => this.renderChart())
                .catch(error => console.error('Chart.js load error:', error));
        } else {
            this.renderChart();
        }
    }

    getStatusBadgeClass(status) {
        if (!status) {
            return 'status-badge';
        }

        const statusClassMap = {
            'Present': 'status-badge present',
            'Absent': 'status-badge absent',
            'Late': 'status-badge late',
            'Half-Day': 'status-badge half-day'
        };

        return statusClassMap[status] || 'status-badge';
    }

    handleUserActions(event) {
        const action = event.detail;

        switch (action.value) {

            case 'authorLoggedIn':
                this.updatePageDataManually();
                break;

            case 'authorLoggedOut':
                this.stopLiveTimer();
                this.isAuthenticated = true; 
                this.attendanceRecords = [];
                this.hoursWorked = '0.00';
                this.progressPercentage = 0;
                break;

            case 'customSearch':
                window.location.href = '/OrbiExchange?query=' + action.queryTerm;
                break;
        }
    }

    startLiveTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
        }

        this.timerInterval = setInterval(() => {
            if (!this.loginDateTime) return;
            const now = new Date();
            const diffMs = now - this.loginDateTime;
            const hours = diffMs / (1000 * 60 * 60);
            this.hoursWorked = hours.toFixed(2);
            if (this.totalWorkingHours) {
                const percentage = (hours / this.totalWorkingHours) * 100;
                this.progressPercentage = percentage.toFixed(2);
            }
        }, 60000);
    }

    stopLiveTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
    }
    
    get progressStyle() {
        const cappedProgress = Math.min(this.animatedProgress, 100);
        const offset = this.circumference - (cappedProgress / 100) * this.circumference;

        return `
            stroke-dasharray:${this.circumference};
            stroke-dashoffset:${offset};
            transition: stroke-dashoffset 0.3s ease;
        `;
    }

    get getTodayProgressStyle() {
        const percentage = Math.min(Number(this.todayData.workingPercentage), 100);
        return `width: ${percentage}%; background-color: #26C6DA;`;
    }

    get getThisWeekProgressStyle() {
        const percentage = Math.min(Number(this.thisWeekData.workingPercentage), 100);
        return `width: ${percentage}%; background-color: #EF5350;`;
    }

    get getThisMonthProgressStyle() {
        const percentage = Math.min(Number(this.thisMonthData.workingPercentage), 100);
        return `width: ${percentage}%; background-color: #FFA726;`;
    }

    get getRemainingProgressStyle() {
        const percentage = Math.min(Number(this.remainingData.workingPercentage), 100);
        return `width: ${percentage}%; background-color: #42A5F5;`;
    }

    get loginStatusClass() {
        return this.isLoggedIn ? 'info-value logged-in' : 'info-value logged-out';
    }

    getLeaveStatusBadgeClass(status) {
        if (!status) return 'status-badge';

        const statusMap = {
            'Approved': 'status-badge present',
            'Applied': 'status-badge late',
            'Rejected': 'status-badge absent'
        };
        return statusMap[status] || 'status-badge';
    }

    get noLeavesFound() {
        return this.leaveDetails.length === 0;
    }

}