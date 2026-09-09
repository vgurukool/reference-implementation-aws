#!/bin/bash
set -e
REGION="us-east-2"
CLUSTER_NAME="cnoe-ref-impl"
echo "▶️  Waking cluster $CLUSTER_NAME (scaling worker nodes to 3 across 3 AZs)..."
NODEGROUP=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query "nodegroups[0]" --output text)
if [ -n "$NODEGROUP" ] && [ "$NODEGROUP" != "None" ]; then
    aws eks update-nodegroup-config \
        --cluster-name $CLUSTER_NAME \
        --nodegroup-name $NODEGROUP \
        --scaling-config minSize=2,desiredSize=3,maxSize=4 \
        --region $REGION
    echo "✅ Nodegroup $NODEGROUP scaling to 3 nodes. Cluster will be ready in ~2 minutes."
else
    echo "⚠️ No nodegroup found for $CLUSTER_NAME."
fi
