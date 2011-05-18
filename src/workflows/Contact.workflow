<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>CheckFormerBoardMember</fullName>
        <description>Former Board Member checkbox is set to True</description>
        <field>Former_Board_Member__c</field>
        <literalValue>1</literalValue>
        <name>Check Former Board Member</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactCommPreftoDoNotContact</fullName>
        <description>Sets Communication Preference to Do Not Contact</description>
        <field>Communication_Preference__c</field>
        <literalValue>Do Not Contact</literalValue>
        <name>Contact Comm Pref to Do Not Contact</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactDoNotCall</fullName>
        <description>Sets Do Not Call to True</description>
        <field>DoNotCall</field>
        <literalValue>1</literalValue>
        <name>Contact Do Not Call</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactDoNotMail</fullName>
        <description>Sets Do Not Mail to True</description>
        <field>Do_Not_Mail__c</field>
        <literalValue>1</literalValue>
        <name>Contact Do Not Mail</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactDoNotSolicit</fullName>
        <description>Sets Do Not Solicit to True</description>
        <field>Do_Not_Solicit__c</field>
        <literalValue>1</literalValue>
        <name>Contact Do Not Solicit</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactDoNotTrade</fullName>
        <description>Sets Do Not Trade to True</description>
        <field>Do_Not_Trade__c</field>
        <literalValue>1</literalValue>
        <name>Contact Do Not Trade</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactEmailOptOut</fullName>
        <description>Sets Email Opt Out to True</description>
        <field>HasOptedOutOfEmail</field>
        <literalValue>1</literalValue>
        <name>Contact Email Opt Out</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactEmailtoNull</fullName>
        <field>Email</field>
        <name>Contact Email to Null</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Null</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactHomePhonetoNull</fullName>
        <field>HomePhone</field>
        <name>Contact Home Phone to Null</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Null</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactMobiletoNull</fullName>
        <field>MobilePhone</field>
        <name>Contact Mobile to Null</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Null</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactMovePhoneEmailtoDescription</fullName>
        <description>for use when making a contact inactive - move all of the contact info to the description field (a later time workflow will delete the original fields)</description>
        <field>Description</field>
        <formula>IF ( Description = &quot;&quot; , &quot;&quot; , Description &amp; BR() &amp; BR() ) &amp;

IF (  Phone = &quot;&quot; , &quot;&quot; , &quot;Work Phone: &quot; &amp; Phone &amp; BR() ) &amp;
IF (  HomePhone = &quot;&quot; , &quot;&quot; , &quot;Home Phone: &quot; &amp; HomePhone &amp; BR() ) &amp;
IF (  MobilePhone = &quot;&quot; , &quot;&quot; , &quot;Mobile: &quot; &amp; MobilePhone &amp; BR() ) &amp;
IF (  OtherPhone = &quot;&quot; , &quot;&quot; , &quot;OtherPhone: &quot; &amp; OtherPhone &amp; BR() ) &amp;
IF (  Email = &quot;&quot; , &quot;&quot; , &quot;Email: &quot; &amp; Email &amp; BR() ) &amp;
IF (   Secondary_Email__c  = &quot;&quot; , &quot;&quot; , &quot;Secondary Email: &quot; &amp; Secondary_Email__c &amp;  BR() )</formula>
        <name>Contact Move Phone Email to Description</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactNewsletterOptOut</fullName>
        <field>Newsletter_Opt_Out__c</field>
        <literalValue>1</literalValue>
        <name>Contact Newsletter Opt Out</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactOtherPhonetoNull</fullName>
        <field>OtherPhone</field>
        <name>Contact Other Phone to Null</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Null</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactPrimaryAddresstoNoMail</fullName>
        <field>Primary_Address__c</field>
        <literalValue>No Mail</literalValue>
        <name>Contact Primary Address to No Mail</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactSecondaryEmailtoNull</fullName>
        <field>Secondary_Email__c</field>
        <name>Contact Secondary Email to Null</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Null</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>ContactWorkPhonetoNull</fullName>
        <field>Phone</field>
        <name>Contact Work Phone to Null</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Null</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>UnmarkBadEmailAddress</fullName>
        <field>Bad_Email_Address__c</field>
        <literalValue>0</literalValue>
        <name>Unmark Bad Email Address</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>Contact - Do Not Mail</fullName>
        <actions>
            <name>ContactPrimaryAddresstoNoMail</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>Contact.Do_Not_Mail__c</field>
            <operation>equals</operation>
            <value>True</value>
        </criteriaItems>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
    <rules>
        <fullName>Contact Inactive or Deceased</fullName>
        <actions>
            <name>ContactCommPreftoDoNotContact</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactDoNotCall</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactDoNotMail</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactDoNotSolicit</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactDoNotTrade</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactEmailOptOut</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactMovePhoneEmailtoDescription</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactNewsletterOptOut</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactPrimaryAddresstoNoMail</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <booleanFilter>1 OR 2</booleanFilter>
        <criteriaItems>
            <field>Contact.Inactive__c</field>
            <operation>equals</operation>
            <value>True</value>
        </criteriaItems>
        <criteriaItems>
            <field>Contact.Deceased__c</field>
            <operation>equals</operation>
            <value>True</value>
        </criteriaItems>
        <description>this one doesn&apos;t include the time trigger so it can be packaged - you should add the time trigger once it&apos;s installed in client instance, using the Example rule in mpdev as a guide</description>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
    <rules>
        <fullName>Contact Inactive or Deceased - Example With Time Trigger</fullName>
        <actions>
            <name>ContactCommPreftoDoNotContact</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactDoNotCall</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactDoNotMail</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactDoNotSolicit</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactEmailOptOut</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactMovePhoneEmailtoDescription</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactNewsletterOptOut</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactPrimaryAddresstoNoMail</name>
            <type>FieldUpdate</type>
        </actions>
        <active>false</active>
        <booleanFilter>1 OR 2</booleanFilter>
        <criteriaItems>
            <field>Contact.Inactive__c</field>
            <operation>equals</operation>
            <value>True</value>
        </criteriaItems>
        <criteriaItems>
            <field>Contact.Deceased__c</field>
            <operation>equals</operation>
            <value>True</value>
        </criteriaItems>
        <description>this one includes time triggers so cannot be packaged - use as guide for how to set up the other rule once installed in client instance</description>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
    <rules>
        <fullName>Do Not Contact</fullName>
        <actions>
            <name>ContactDoNotCall</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactDoNotMail</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactDoNotSolicit</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactDoNotTrade</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>ContactEmailOptOut</name>
            <type>FieldUpdate</type>
        </actions>
        <active>false</active>
        <criteriaItems>
            <field>Contact.Communication_Preference__c</field>
            <operation>equals</operation>
            <value>Do Not Contact</value>
        </criteriaItems>
        <description>Causes field updates when Communication Preference is set to Do Not Contact

9/2 MS: not sure we want this one in here, I&apos;d prefer to keep Communication Preference as something anecdotal and potentially temporary, w/o so many consequences</description>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
    <rules>
        <fullName>Uncheck BOD checks fmr BOD</fullName>
        <actions>
            <name>CheckFormerBoardMember</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <description>Unchecking Board Member checks Former Board Member</description>
        <formula>AND( ISCHANGED(Board_Member__c),!Board_Member__c)</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
    <rules>
        <fullName>Unmark Bad Email Address</fullName>
        <actions>
            <name>UnmarkBadEmailAddress</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <description>Unchecks the Bad Email Address flag if Email is changed.</description>
        <formula>ISCHANGED(Email)</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
