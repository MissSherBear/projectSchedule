import { LightningElement, api, wire, track } from 'lwc';
import getProjectActivities from '@salesforce/apex/ProjectScheduleController.getProjectActivities';
import updateActivityDate from '@salesforce/apex/ProjectScheduleController.updateActivityDate';

const COLUMNS = [
    { label: 'Activity / Section Name', fieldName: 'name', 
        cellAttributes: {class:{fieldName:'cssClass'}} 
    },
    { label: 'Status', fieldName: 'activityStatus' },
    { label: 'Original Budget Cost', fieldName: 'originalBudget', type: 'currency' },
    { label: 'Current Budget Cost', fieldName: 'currentBudget', type: 'currency' },
    { label: 'Est Committed Cost', fieldName: 'estimatedCost', type: 'currency' },
    { label: 'Est Committed % of Budget', fieldName: 'percent', type: 'percent' }
];

export default class ProjectSchedule extends LightningElement {
    @api recordId;  // Project Id
    treeData = [];
    columns = COLUMNS;
    projectActivities = [];
    error;

    @wire(getProjectActivities, { projectId: '$recordId' })
    wiredActivities({ error, data }) {
        if (data) {
            console.log('Fetched Data ' + JSON.stringify(data));
            console.log(data);
            try {
                this.projectActivities = data.map(section => {
                    return {
                        ...section,
                        activities: section.activities.map(activity => ({
                            ...activity,
                            statusClass: this.getActivityStatusClass(activity.activityStatus),
                            forecastDate: activity.forecastDate || '',
                            // currencyDisplay: this.getCurrencyDisplay(activity),
                            // percentDisplay: this.getPercentDisplay(activity),
                            financeLines: activity.financeLines || []  // Handle financeLines being undefined

                        }))
                    };
                });
                this.error = undefined;
            } catch (err) {
                this.error = err;
                console.error('Error while processing data:', err);
            }
        } else if (error) {
            this.error = error;
            this.projectActivities = [];
            console.error('Error while fetching data:', error);
        }
    }

    // Getter method to return the CSS class for each Activity status 
    getActivityStatusClass(status) {
        if (status === 'Completed') {
            return 'slds-badge completed';
        } else if (status === 'In Progress') {
            return 'slds-badge in-progress';
        } else if (status === 'Overdue') {
            return 'slds-badge overdue';
        }
        return 'hidden'; // Return an empty string if none of the statuses match
    }

    toggleSection(event) {
        const sectionId = event.currentTarget.dataset.id;
        const rows = this.template.querySelectorAll(`tr[data-section="${sectionId}"]`);
        rows.forEach(row => {
            row.classList.toggle('hidden');
        });
        // Switch icon from chevronright to chevrondown
        const icon = event.currentTarget.querySelector('lightning-icon');
        icon.iconName = icon.iconName === 'utility:chevronright' ? 'utility:chevrondown' : 'utility:chevronright';
    }
    
    toggleActivity(event) {
        const activityId = event.currentTarget.dataset.id;
        const rows = this.template.querySelectorAll(`tr[data-parent="${activityId}"]`);
        rows.forEach(row => {
            row.classList.toggle('hidden');
        });
        // Switch icon from chevronright to chevrondown
        const icon = event.currentTarget.querySelector('lightning-icon');
        icon.iconName = icon.iconName === 'utility:chevronright' ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // Buttons to expand/collapse all sections
    expandAll() {
        const sections = this.template.querySelectorAll('.section-header');
        sections.forEach(section => {
            section.classList.remove('hidden');
            const icon = section.querySelector('lightning-icon');
            icon.iconName = 'utility:chevrondown';
        });
        const activities = this.template.querySelectorAll('.activity-row');
        activities.forEach(activity => {
            activity.classList.remove('hidden');
        });
    }

    collapseAll() {
        const sections = this.template.querySelectorAll('.section-header');
        sections.forEach(section => {
            section.classList.add('hidden');
            const icon = section.querySelector('lightning-icon');
            icon.iconName = 'utility:chevronright';
        });
        const activities = this.template.querySelectorAll('.activity-row');
        activities.forEach(activity => {
            activity.classList.add('hidden');
        });
    }

    handleFocus(event) {
        event.target.type = 'date';
    }
    handleBlur(event) {
        if (!event.target.value) {
            event.target.type = 'text';
        }
    } 


    handleDateChange(event) {
        const activityId = event.target.dataset.id;
        const field = event.target.dataset.field;
        const newValue = event.target.value;

        // Update the local data
        this.projectActivities = this.projectActivities.map(section => {
            section.activities = section.activities.map(activity => {
                if (activity.id === activityId) {
                    activity[field] = newValue;
                }
                return activity;
            });
            return section;
        });

        // Call the Apex method to update the record
        updateActivityDate({ activityId, fieldName: field, newValue })
            .then(() => {
                console.log('Date updated successfully');
            })
            .catch(error => {
                console.error('Error updating date:', error);
            });
    }


    // mapChildrenToUnderscore(node) {
    //     let mappedNode = { ...node };
    //     // Set default expansion for sections
    //     if (node.isSection) {
    //         mappedNode._children = node.children.map(child => this.mapChildrenToUnderscore(child));
    //         mappedNode.expanded = true; // Always expand sections
    //         mappedNode.cssClass = 'section-header'; // Apply SLDS accordion styling
    //     } else if (node.children) {
    //         mappedNode._children = node.children.map(child => this.mapChildrenToUnderscore(child));
    //         delete mappedNode.children; // Remove the original 'children'
    //     }
    //     return mappedNode;
    // }

    clickToExpandAll(e) {
        const grid =  this.template.querySelector('lightning-tree-grid');
        grid.expandAll();
    }

    clickToCollapseAll(e) {
        const grid =  this.template.querySelector('lightning-tree-grid');
        grid.collapseAll();
    }
}