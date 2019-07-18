


# ZRemoteObject

***Custom Remote Object Model Framework to handle Remote object call on a complex object***


**Setup:**

Add the ZRemoteObject.cls file to your org and refer it in your Apex Controller. Then add more 3 files for each implementation and refer the same ZRemoteObject class. 

Please refer below snippets for examples.



**Visualforce Page :**
```html
<apex:remoteObjects>
	<apex:remoteObjectModel 
		name="<AnyObject>" 
		fields="<CommaSeperatedFields>" 
		retrieve="{!$RemoteAction.<YourCustomController>.<YourCustomFunctionRemoteAction>}" 
	/>
</apex:remoteObjects>
```

**Javascript :**


```javascript

var model = new SObjectModel.<AnyDefinedObjectAbove>(); //Define once use it everywhere.

var fetchOptions = {
	// Number of record items to fetch
	limit: 100,
	// When passing multiple objects offset needs to be an object {Opportunity : 100, Lead : 30} 
	// #Lookup:001 //You need to store the offsets in UI to page backward.
	offset: 300, 
	//If Multiple only first object will be considered as Primary in SOQL building, if multiple mapping then SOQL Orderby is ignored and sortList is invoked.
	orderby: [{status : 'ASC'}],
	//Can pass any custom object if required in @RemoteAction and will be ignored by the Framework
	view: val,
	//mapping can be multiple objects -> data is collated in a single list and referred to as the keys so from JSON records[i].status will hold (StageName in Opportunity and Status in Lead)
	,mapping: {
		 Opportunity: {
			 id: 'id', 
			 ownerLastName: 'Owner.LastName', 
			 name: 'Account.Name', 
			 firstName: 'Account.FirstName', 
			 status: 'StageName', 
			 subStatus : |*#Lookup:002*|{formula:'{0}=="Closed Won"?{1}:{2}',
			 fieldset: ['StageName','ERP_Won_Status__c','Reason_Lost__c']}},
			 Lead: {
				 id: 'id', 
				 ownerLastName : 'Owner.LastName', 
				 name : 'name', 
				 firstName: 'firstName', 
				 status: 'Status', 
				 subStatus: 'Unqualified_Declined_Reason__c', 
				 extra : 'Referral_Code__c'
			}
	}
	,where	: {
		Referral_Program__c: {
			in: ['BAC', 'BAC Enterprise'] 
		},
		//status is the key and qualified name for (StageName in Opportunity and Status in Lead)
		status: {
			in : ['Unqualified', 'Closed Lost']	 
		} 
	}
};

model.retrieve(JSON.stringify(fetchOptions), function(records, error, event) {
	//records -> Standard field (will not hold data anymore)
	//error -> on error
	//event.result -> will have the JSON object sent from ZRemoteObject.cls
	//<return new Map<String, Object> {'records' => results, 'countRecords' => countRecords};> -> event.result.records and event.result.countRecords can be accessed here.
});

```


**Apex Controller (@RemoteAction) :**
```java
@RemoteAction
public static Map<String, Object> retrieveData(String type, List<String> fields, String criteria){
	
	// 1) One way of doing things deserialize it and obtain proper objects (will be marshalled)
	
	Map<String, Object> criteriaMap = (Map<String, Object>)JSON.deserializeUntyped(criteria);
	List<Map<String,Object>> results = ZRemoteObject.fetch(criteriaMap);
	Integer countRecords = ZRemoteObject.countQuery(criteriaMap);
	Map<String, Object> customResult = new Map<String, Object> {
					'records' => results, 
					'countRecords' => countRecords
	};
	return customResult;
	
	// 2) Another way of doing things pass String directly and obtain proper objects (will be marshalled)
	
	List<Map<String,Object>> results = ZRemoteObject.fetch(criteria);
	Integer countRecords = ZRemoteObject.countQuery(criteria);
	Map<String, Object> customResult = new Map<String, Object> {
					'records' => results, 
					'countRecords' => countRecords
	};
	return customResult;
	
	// 3) Can directly pass string and JSON will be marshalled 1 call to get records + count 
	return ZRemoteObject.fetchWithCount(criteria);	
}
```
______________________________________________________________________________________________________

**#Lookup: 001 :** 
*NOTE*: You can call your javascript anyhow you like this is just one way of doing things.
only in case of wrappers
(In case if you have one object to deal with you can supply an integer offset which is multiple of your limit it will work and you don't need this [eg 100, 200, 300, etc when limit = 100])

```js
// #Step : 1
// Declare these following variables in a clousure accessible to below fn <gatherOffset>
var offset			= 0;
var mappedOffset	= {};
var pagedOffsets	= [];
var paged			= 0;
var workset			= {};
var totalCount		= 0;

// #Step : 2
//populate above vars
model.retrieve(JSON.stringify(fetchOptions),function(records,error,event){
	workset = event.result.records; //will be used to determine next paging offset below fn <gatherOffset>
	totalCount = event.result.countRecords || totalCount;
});

// #Step : 3
//Call a fn that will fetch the next offset 
//if paged = +1 paginated forward 
//or paged = 0 means same page refreshed/reloaded 
//or paged = -1 means reverse pagination

fetchOptions.offset = gatherOffset(workset,offset,paged,fetchOptions.mapping,mappedOffset,pagedOffsets,fetchLimit);
//Defined below

// #Step : 4
//Keep calm and code away
var gatherOffset = function(w,o,p,s,m,ps,l){ 
	// w = current displayed workset the recordList that is sent from here (every row in this list contains a key type of Object it is holding)
	// o is the current offset based on number of records found out intially based on totalRecords for multiple objects
	// p is the direction of paging +1 0 -1
	// s is the mapping intention to check if offset will be an object or a number based on mapping
	// m is the current mappedoffset that is sent to Remote object call e.g {Opportunity : 100, Lead : 30}
	// ps is the array which collates all the mappedOffset so it is easy to navigate if it has the current offset pagenumber then return else locate by iterating workset
	// l is the fetch limit
	
	if(Object.keys(s).length==1){
		return !o ? undefined : o;//if there is only one mapping it will return integer say multiples of limit [eg 100, 200, 300, etc when limit = 100]
	} else {
		m = ps[((o||0)/l)] || {};//if paged data available/ first time load
		if(p>0  && $.isEmptyObject(m)){ //forward paging
			m = $.extend({},ps[((o||0)/l)-1]); //get last paging and add to it the current workset type records
			$.each(w,function(k,v){
				m[v.type] && m[v.type]++ || (m[v.type]=1);//determine next offset 
			});
		}
		ps[((o||0)/l)] = m; //update in pagedOffset Array
		return m;
	}
};
```

**#Lookup:002 :**
	
```js 
subStatus : {
	formula: '{0}=="Closed Won"?{1}:{2}',
	fieldset:['StageName','ERP_Won_Status__c','Reason_Lost__c']
}	
```
Right now the formula thingy is not implemented, the recommended way is to create a formula field and put it there.
	Complications in building formula field is the complexity as it is called multiple times and APEX has something called Tooling API 
	other methods to "ExecuteAnnonymousCode" didn't do the trick (can be looked into in the future)

---

This piece of code was implemented to get data out of salesforce with custom controls over RemoteObjects especially in Salesforce One. 
Key implementations :


- When you want to fetch data from 2  objects parallely merging data streams
- When you want to fetch data over SOQL limits
- Any other custom implementations on fetching data with morphed results

Experimental project tryout. Please feel free to contact me for queries

Author: **Joy Biswas**
