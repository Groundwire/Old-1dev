<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>Set_VR_Bounced</fullName>
        <field>Bounced__c</field>
        <literalValue>1</literalValue>
        <name>Set VR Bounced</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>Set_VR_Clicked</fullName>
        <field>Clicked__c</field>
        <literalValue>1</literalValue>
        <name>Set VR Clicked</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>Set_VR_Opened</fullName>
        <field>Opened__c</field>
        <literalValue>1</literalValue>
        <name>Set VR Opened</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>Set_VR_Sent</fullName>
        <field>Sent__c</field>
        <literalValue>1</literalValue>
        <name>Set VR Sent</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>Set_VR_Unsubscribed</fullName>
        <field>Unsubscribed__c</field>
        <literalValue>1</literalValue>
        <name>Set VR Unsubscribed</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>Campaign Member Update VR Bounced</fullName>
        <actions>
            <name>Set_VR_Bounced</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>Set_VR_Sent</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>CampaignMember.Status</field>
            <operation>equals</operation>
            <value>Bounced</value>
        </criteriaItems>
        <description>Update the Vertical Response checkboxes based off the CM&apos;s status.</description>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
    <rules>
        <fullName>Campaign Member Update VR Clicked</fullName>
        <actions>
            <name>Set_VR_Clicked</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>Set_VR_Opened</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>Set_VR_Sent</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>CampaignMember.Status</field>
            <operation>equals</operation>
            <value>Clicked</value>
        </criteriaItems>
        <description>Update the Vertical Response checkboxes based off the CM&apos;s status.</description>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
    <rules>
        <fullName>Campaign Member Update VR Opened</fullName>
        <actions>
            <name>Set_VR_Opened</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>Set_VR_Sent</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>CampaignMember.Status</field>
            <operation>equals</operation>
            <value>Opened</value>
        </criteriaItems>
        <description>Update the Vertical Response checkboxes based off the CM&apos;s status.</description>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
    <rules>
        <fullName>Campaign Member Update VR Sent</fullName>
        <actions>
            <name>Set_VR_Sent</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>CampaignMember.Status</field>
            <operation>equals</operation>
            <value>Sent</value>
        </criteriaItems>
        <description>Update the Vertical Response checkboxes based off the CM&apos;s status.</description>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
    <rules>
        <fullName>Campaign Member Update VR Unsubscribed</fullName>
        <actions>
            <name>Set_VR_Opened</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>Set_VR_Sent</name>
            <type>FieldUpdate</type>
        </actions>
        <actions>
            <name>Set_VR_Unsubscribed</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>CampaignMember.Status</field>
            <operation>equals</operation>
            <value>Unsubscribed</value>
        </criteriaItems>
        <description>Update the Vertical Response checkboxes based off the CM&apos;s status.</description>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
</Workflow>
