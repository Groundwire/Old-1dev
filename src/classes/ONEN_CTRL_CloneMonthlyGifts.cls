public virtual class ONEN_CTRL_CloneMonthlyGifts {
// Written by Matthew Scholtz and Dave Manelski, copyright (c) 2009 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	public string YearSelection { get; set; }
	public boolean showProgress { get; set; } 
	
	// status string warning message.
    public String cloneWarningMsg { get; set; }

	public ONEN_CTRL_CloneMonthlyGifts () {
        // if in 1st quarter of year, default to last year, otherwise this year
        MonthlyGiftsSettings__c settings = MonthlyGiftsSettings__c.getOrgDefaults();
		if (system.today().month() <= settings.Months_Default_to_Last_Year__c) {
        	YearSelection = 'LAST_YEAR';
        } else {
        	YearSelection = 'THIS_YEAR';
        }
	}
	
	
    public List<SelectOption> getYearOptions() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('THIS_YEAR',string.valueOf(System.Today().Year())));
        options.add(new SelectOption('LAST_YEAR',string.valueOf(System.Today().Year()-1)));
        return options;
    }
	
	// public Set<Id> EntireSelectedList = new Set<Id> ();
	
	
	public pageReference cloneOpps() {
		
		String searchYear;
		if ( YearSelection == 'THIS_YEAR' ) {
			searchYear = 'NEXT_YEAR';
		} else {
			searchYear = 'THIS_YEAR';
		}
		String soql = 'SELECT Id from Opportunity WHERE Monthly_Gift__c = true AND CloseDate = ' + searchYear + ' LIMIT 100';
		List<Opportunity> countMonthlyGifts = Database.query(soql); 
		
		if (countMonthlyGifts.size()>20) {
			showProgress = false;
			cloneWarningMsg = 'There are already a number of monthly gifts already created this year.  Are you sure you wish to proceed?';
			return null;
		} else {
			showProgress = true;
			id batchinstanceid = database.executeBatch(new ONEN_BATCH_CloneMonthlyGifts(YearSelection), 25);
			//PageReference p = new PageReference('/apexpages/setup/listAsyncApexJobs.apexp');
			//p.setRedirect(true);
			//return p;
			return null;
		}
	}
	
	static testMethod void testThisYear(){
        
        MonthlyGiftsSettings__c settings = MonthlyGiftsSettings__c.getOrgDefaults();
        settings.Months_Default_to_Last_Year__c = 0;
        update settings;
        
        Test.StartTest();
        ONEN_CTRL_CloneMonthlyGifts controller = new ONEN_CTRL_CloneMonthlyGifts();
        controller.getYearOptions();
        controller.cloneOpps();
    	Test.StopTest();
    }
    
    static testMethod void testLastYear(){
        
        MonthlyGiftsSettings__c settings = MonthlyGiftsSettings__c.getOrgDefaults();
        settings.Months_Default_to_Last_Year__c = 12;
        update settings;
        
        Test.StartTest();
        ONEN_CTRL_CloneMonthlyGifts controller = new ONEN_CTRL_CloneMonthlyGifts();
        controller.getYearOptions();
        controller.cloneOpps();
    	Test.StopTest();
    }
    
    static testMethod void alreadyCloned(){
        
        // create & insert contact(s)
		Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( 25 );
		insert TestCons;

		// create new opps 
		Date datClose = Date.newInstance(System.Today().Year(),12,31); 
		Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCons, null, 'Closed Won', datClose, 25 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS ,null);
        for (Opportunity opp : newOpps) {
        	opp.Monthly_Gift__c = true;
        	opp.Monthly_Gift_Amount__c = 25;
        }
        insert newOpps;
        
        
        Test.StartTest();
        ONEN_CTRL_CloneMonthlyGifts controller = new ONEN_CTRL_CloneMonthlyGifts();
        controller.getYearOptions();
        controller.yearSelection = 'LAST_YEAR';
        controller.cloneOpps();
        system.assertEquals(controller.showProgress, false);
        system.assertNotEquals(controller.cloneWarningMsg,null);
        Test.StopTest();
    }
    
}